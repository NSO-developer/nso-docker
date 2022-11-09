#!/usr/bin/env python3

import argparse
import os
import re
import subprocess
import sys
import time
from enum import Enum, auto
from typing import Optional

class Colors():
    SUCCESS = '\033[92m'
    ERROR = '\033[91m'
    INFO = '\033[93m'
    ENDC = '\033[0m'


class TimeLimitExceeded(Exception):
    pass


class CliStyle(Enum):
    Cisco = auto()
    Juniper = auto()


def _cmd_fail(result, seconds):
    print(f'{Colors.ERROR}=== {seconds}s elapsed - Failed command, start output ============={Colors.ENDC}')
    print(f'{Colors.ERROR}{result}{Colors.ENDC}')
    print(f'{Colors.ERROR}=== {seconds}s elapsed - Failed command, end output ==============={Colors.ENDC}')

_prev_fail_result = ''

def cmd_fail(result: str, seconds: int, will_retry: bool, suppress_fail=False):
    global _prev_fail_result
    if _prev_fail_result != result and not suppress_fail:
        _cmd_fail(result, seconds)
        if will_retry:
            print(f'{Colors.ERROR}>>> {seconds}s elapsed - Failed command, retrying after every 5 second sleep...{Colors.ENDC}')
            print(f'{Colors.ERROR}>>> No more output until result changes{Colors.ENDC}')
        _prev_fail_result = result
    if not will_retry and suppress_fail:
        # no more retries, need to print the last output
        _cmd_fail(result, seconds)


def cmd_success(result: str, seconds: int):
    print(f'{Colors.SUCCESS}=== {seconds}s elapsed - Successful command, start output ============={Colors.ENDC}')
    print(f'{Colors.SUCCESS}{result}{Colors.ENDC}')
    print(f'{Colors.SUCCESS}=== {seconds}s elapsed - Successful command, end output ==============={Colors.ENDC}')


def _format_command(nso_cnt: str, command: str) -> str:
    escaped_command = command.replace("'", "\\'")
    return f"""docker exec {nso_cnt} bash -lc "echo -e '{escaped_command}' | ncs_cli --noninteractive --stop-on-error -u admin 2>&1" """

def execute_command(nso_cnt: str, command: str, success_pattern: Optional[str] = None, fail_pattern: Optional[str] = None,
                    time_limit: Optional[int] = None, retry: bool = False, shell: bool = False, suppress_error: bool = True) -> bool:
    if shell:
        execute = command
    else:
        execute = _format_command(nso_cnt, f'unhide debug\n{command}')
    print(f'{Colors.INFO}>>> Executing: {execute}{Colors.ENDC}')

    start_time = time.time()
    def will_retry():
        nonlocal retry, start_time, time_limit
        if not hasattr(will_retry, 'first'):
            will_retry.first = True
            return True
        if retry:
            return start_time + time_limit > time.time()
        else:
            return False

    while will_retry():
        # (GitLab) CI runners do not like buffered output
        sys.stdout.flush()

        try:
            result = subprocess.check_output(execute, shell=True, stderr=subprocess.STDOUT).decode('utf-8')
        except subprocess.CalledProcessError as cpe:
            # "ncs_cli --stop-on-error" exits with exit code 8 on syntax and
            # other application errors
            result = cpe.output.decode('utf-8')
            if cpe.returncode == 8:
                cmd_fail(f'"ncs_cli --stop-on-error" stopped execution:\n\n{result}', int(time.time() - start_time), will_retry(), suppress_error)
            else:
                if re.search(r'No such container', result, re.MULTILINE):
                    print(f'{Colors.ERROR}No NSO container {nso_cnt} - exiting immediately{Colors.ENDC}')
                    exit(1)
                cmd_fail(f'{cpe}:\n\n{result}', int(time.time() - start_time), will_retry(), suppress_error)
        except Exception as e:
            print(f'{Colors.ERROR}{e}{Colors.ENDC}')
            cmd_fail('Unhandled exception executing command', int(time.time() - start_time), will_retry(), suppress_error)
        else:
            seconds = int(time.time() - start_time)

            if fail_pattern:
                if re.search(fail_pattern, result, re.MULTILINE):
                    cmd_fail(result, seconds, will_retry=False, suppress_fail=False)
                    return False

            if success_pattern:
                if re.search(success_pattern, result, re.MULTILINE):
                    cmd_success(result, seconds)
                    return True
                else:
                    cmd_fail(result, seconds, will_retry(), suppress_error)
            else:
                cmd_success(result, seconds)
                return True
        if retry:
            time.sleep(5)

    if retry:
        raise TimeLimitExceeded()
    else:
        return False


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('command', help='Command(s) to run. By default these are executed in NSO (using ncs_cli), unless overridden with the --shell argument.')
    parser.add_argument('-n', '--nso-cnt', help='Name of NSO docker container.', default=os.getenv('NSO_CNT', 'ncs-test'))
    cli_group = parser.add_mutually_exclusive_group()
    cli_group.add_argument('-C', '--cisco', help='Use Cisco -style NSO CLI', action='store_const', const=CliStyle.Cisco, dest='cli_style')
    cli_group.add_argument('-J', '--juniper', help='Use Juniper -style NSO CLI', action='store_const', const=CliStyle.Juniper, dest='cli_style')
    parser.add_argument('-s', '--success-pattern', help='Exit successfully if pattern matches output. If pattern is omitted, the output passes through unchecked.')
    parser.add_argument('-f', '--fail-pattern', help='Fail immediately if pattern matches output. If pattern is omitted, the command may be retried.')
    parser.add_argument('-t', '--time-limit', help='Time limit for execution of command', default=300, type=int)
    parser.add_argument('-r', '--retry', help='Retry command on failure. A failure condition is either ncs_cli exiting on error or the --success-pattern not matching.', action='store_true')
    parser.add_argument('-e', '--on-fail', help='Command(s) to execute after failure (after retries are exhausted). If executing NSO commands, defaults to "show al:alarms".')
    parser.add_argument('-b', '--shell', help='execute the command in shell, not NSO CLI', dest='shell', action='store_true')
    parser.add_argument('--suppress-error', help='Suppress error output during retries, the final error will still gets printed', action='store_true')
    args = parser.parse_args()

    success = False
    try:
        success = execute_command(args.nso_cnt, args.command, args.success_pattern, args.fail_pattern,
                                  args.time_limit, args.retry, args.shell, args.suppress_error)
    except TimeLimitExceeded:
        print(f'{Colors.ERROR}Time limit of {args.time_limit}s exceeded{Colors.ENDC}')
    except Exception as e:
        print(f'{Colors.ERROR}{e}{Colors.ENDC}')

    if not success:
        on_fail = 'show al:alarms' if not args.on_fail and not args.shell else args.on_fail
        if on_fail:
            print(f'{Colors.INFO}Executing on-fail command {on_fail}{Colors.ENDC}')
            execute_command(args.nso_cnt, on_fail, shell=args.shell)

    exit(0 if success else 1)
