# -*- mode: python; python-indent: 4 -*-
import ncs
from ncs.dp import Action

import bar

def test():
    return bar.test()

class TestAction(Action):
    @Action.action
    def cb_action(self, uinfo, name, kp, action_input, action_output):
        action_output.message = "Hello world from Python pyvenv-b"


class Main(ncs.application.Application):
    def setup(self):
        self.log.info('Main RUNNING')

        self.register_action('test-pyvenv-b-actionpoint', TestAction)


    def teardown(self):
        self.log.info('Main FINISHED')
