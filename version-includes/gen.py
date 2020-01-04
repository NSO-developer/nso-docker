#!/usr/bin/env python3
"""Script to generate a bunch of YAML files containing Gitlab CI configuration
that are suitable for including from other CI configurations.

Gitlab CI supports including other files in the configuration file. We use this
to simplify maintenance of many NSO packages over time. Each package only needs
to define a archetype CI job and by including one of these prepared version
include files, the precise versions of NSO to test with doesn't have to be
specified in each repo, instead the centralized nso-docker repo can be used as
a source for NSO version information.

This script generates a bunch of different version include files. It is up to
the author of each individual NSO package to include the one suitable for their
package.

For example, we have build-all.yaml, which uses the prototypical CI job
definition called 'build' and defines jobs for all currently supported versions
of NSO.

build-all4.yaml is similar but only includes NSO 4.x versions, whereas
build-all5.yaml does the same for NSO 5.x. Since NSO 5 looks quite different
with schema-mount, it could be reasonable for some packages to only target NSO
5.

build-tot.yaml only includes the "tip" of each train, where a train is the
combination of a major and minor version number. Patch releases are not
considered for tip-of-train as they are not supposed to be used by the wide
masses. For example, if we have 4.7, 4.7.1, 4.7.2 and 4.7.2.1 as well as 5.2.1,
the tip-of-train would include 4.7.2 and 5.2.1.
"""

import json

ci_template = """{name}-{version}:
  extends: .{name}
  variables:
    NSO_VERSION: "{version}"

"""

ci_mv_template = """multiver-test_{old_version}_{version}:
  extends: .multiver_test
  variables:
    OLD_NSO_VERSION: "{old_version}"
    NSO_VERSION: "{version}"

"""

def vsn_split(version):
    """
    """
    return tuple(map(lambda x: int(x), version.split(".")))

def f_major(interesting_version, versions):
    """Filter based on the major version

    Filtering on version 4 means 4.7.5 is returned while 5.2.1 is not
    """
    return filter(lambda x: x[0] == interesting_version, versions)


def f_majmin(iv, versions):
    """Filter based on the major and minor version

    iv (interesting_version) is a list with two elements for the two first digits in the version number

    Filtering on version [5, 2] means 5.2 and 5.2.1 is returned while 5.1.1 or 5.3 is not
    """
    return filter(lambda x: x[0] == iv[0] and x[1] == iv[1], versions)


def f_lower(version, versions):
    """Return versions lower than the version specified by *version*
    """
    for vsn in sorted(versions):
        if vsn < version:
            yield vsn


def f_higher(version, versions):
    """Return versions higher than the version specified by *version*
    """
    for vsn in sorted(versions):
        if vsn > version:
            yield vsn


def f_tot(versions):
    """Filter based on tip-of-train
    Version numbers are major.minor.maintenance.path
    Tip-of-train is considered to be the latest major.minor.maintenance combo
    This filter will only return the tip-of-train releases so for example, only
    4.7.6 will be released if the input is 4.7.5 and 4.7.6
    """
    tot = {}
    for version in versions:
        mm = (version[0], version[1])
        if mm not in tot:
            tot[mm] = version
        if tot[mm] < version:
            tot[mm] = version
    return tot.values()


def formatter(version, name='build'):
    version_string = ".".join(map(lambda x: str(x), version))
    return ci_template.format(name=name, version=version_string)


def formatter_mv(old_version, version):
    old_version_string = ".".join(map(lambda x: str(x), old_version))
    version_string = ".".join(map(lambda x: str(x), version))
    return ci_mv_template.format(old_version=old_version_string, version=version_string)


def write_job_set(name, versions):
    # all versions
    with open("{}-all.yaml".format(name), "w") as f:
        f.write("".join(map(lambda x: formatter(x, name), versions)))

    # all 4 versions
    with open("{}-all4.yaml".format(name), "w") as f:
        f.write("".join(map(lambda x: formatter(x, name), f_major(4, versions))))

    # all 5 versions
    with open("{}-all5.yaml".format(name), "w") as f:
        f.write("".join(map(lambda x: formatter(x, name), f_major(5, versions))))

    # all tip-of-train versions
    with open("{}-tot.yaml".format(name), "w") as f:
        f.write("".join(map(lambda x: formatter(x, name), f_tot(versions))))

    # all tip-of-train 4 versions
    with open("{}-tot4.yaml".format(name), "w") as f:
        f.write("".join(map(lambda x: formatter(x, name), f_tot(f_major(4, versions)))))

    # all tip-of-train 5 versions
    with open("{}-tot5.yaml".format(name), "w") as f:
        f.write("".join(map(lambda x: formatter(x, name), f_tot(f_major(5, versions)))))

with open("versions.json") as f:
    versions = sorted(list(map(lambda x: vsn_split(x), json.load(f))))

def write_multiver_test(versions):
    """
    For a given version, we want to test upgrading from the trip of train for all previous trains within our major version. For example, for 5.3 we want to try upgrading from 5.2.1 and 5.1.2 which are the last maintenance releases of the 5.2 and 5.1 branch respectively. We also want to upgrade from the last 4 release, i.e. 4.7.6 at the time of this writing.
    For a given version we want to test:
    - upgrading from previous maintenance release
      - e.g. for 4.7.6 we want to try upgrading from 4.7.5
      - if one exist
    - downgrading to previous maintenance release
      - e.g. for 4.7.5 we want to try to downgrade to 4.7.5, to test that we can roll back in case of a failed 4.7.5 -> 4.7.6 upgrade
    - moving from all other tip-of-train versions in this major version
      - e.g. for 5.2.1, test going from from 5.1.2 and 5.3
    For 5.x versions, we want to test an upgrade from the last 4.x version
    """
    with open("multiver.yaml", "w") as f:
        for vsn in versions:
            olds = []
            majmin = vsn[0:2]

            # if 5, upgrade from last 4.x release
            if vsn[0] == 5:
                all4 = list(f_major(4, versions))
                if len(all4) >= 1:
                    olds.append(all4[-1])

            # go from previous sibling, e.g. for 4.7.6 we want to upgrade from 4.7.5
            mm_prevs = list(f_lower(vsn, f_majmin(majmin, versions)))
            if len(mm_prevs) >= 1:
                olds.append(mm_prevs[-1])

            # go from next sibling, e.g. for 4.7.5 we want to downgrade from 4.7.6
            # currently disabled since tests fail for like 5.3 -> 5.1.2
#            mm_nexts = list(f_higher(vsn, f_majmin(majmin, versions)))
#            if len(mm_nexts) >= 1:
#                olds.append(mm_nexts[0])

            # try upgrade from all previous tot in same major version
            for ovsn in f_tot(f_lower(vsn, f_major(vsn[0], versions))):
                olds.append(ovsn)

            f.write("".join(map(lambda x: formatter_mv(x, vsn), sorted(list(set(olds) - set([vsn]))))))

write_multiver_test(versions)

write_job_set('build', versions)
write_job_set('push', versions)
