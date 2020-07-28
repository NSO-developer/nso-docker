# -*- mode: python; python-indent: 4 -*-
import ncs
from ncs.dp import Action

import foo

class TestAction(Action):
    @Action.action
    def cb_action(self, uinfo, name, kp, action_input, action_output):
        action_output.message = "Hello world from Python"


class Main(ncs.application.Application):
    def setup(self):
        self.log.info('Main RUNNING')

        self.register_action('test-python-actionpoint', TestAction)


    def teardown(self):
        self.log.info('Main FINISHED')
