# -*- mode: python; python-indent: 4 -*-
import ncs
from ncs.dp import Action

from testpkg_python_b import main as tpb
import foo

class TestAction(Action):
    @Action.action
    def cb_action(self, uinfo, name, kp, action_input, action_output):
        action_output.message = f"Hello world from Python pyvenv-a: {tpb.test()}"


class Main(ncs.application.Application):
    def setup(self):
        self.log.info('Main RUNNING')

        self.register_action('test-pyvenv-a-actionpoint', TestAction)


    def teardown(self):
        self.log.info('Main FINISHED')
