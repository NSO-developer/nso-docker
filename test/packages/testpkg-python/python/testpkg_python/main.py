# -*- mode: python; python-indent: 4 -*-
import ncs
import _ncs
from ncs.dp import Action

class TestAction(Action):
    @Action.action
    def cb_action(self, uinfo, name, kp, action_input, action_output):
        action_output.message = "Hello world from Python"

class DecryptAction(Action):
    @Action.action
    def cb_action(self, uinfo, name, kp, action_input, action_output, t):
        maapi = ncs.maapi.Maapi()
        maapi.install_crypto_keys()
        pycnt = ncs.maagic.get_node(t, kp)
        cleartext = _ncs.decrypt(pycnt.encrypted_value)
        action_output.message = f"cleartext: {cleartext}"


class Main(ncs.application.Application):
    def setup(self):
        self.log.info('Main RUNNING')

        self.register_action('test-python-actionpoint', TestAction)
        self.register_action('python-decrypt-actionpoint', DecryptAction)


    def teardown(self):
        self.log.info('Main FINISHED')
