package com.example.testpkgjava;

import com.example.testpkgjava.namespaces.*;
import java.util.List;
import java.util.Properties;
import com.tailf.conf.*;
import com.tailf.navu.*;
import com.tailf.ncs.ns.Ncs;
import com.tailf.dp.*;
import com.tailf.dp.annotations.*;
import com.tailf.dp.proto.*;
import com.tailf.dp.services.*;


public class testpkgjavaRFS {

    /**
     * Init method for java-test action
     */
    @ActionCallback(callPoint="test-java-actionpoint", callType=ActionCBType.INIT)
    public void init(DpActionTrans trans) throws DpCallbackException {
    }

    /**
     * java-test
     */
    @ActionCallback(callPoint="test-java-actionpoint", callType=ActionCBType.ACTION)
    public ConfXMLParam[] selftest(DpActionTrans trans, ConfTag name,
                                   ConfObject[] kp, ConfXMLParam[] params)
    throws DpCallbackException {
        try {
            // Refer to the service yang model prefix
            String nsPrefix = "testpkg-java";

          return new ConfXMLParam[] {
              new ConfXMLParamValue(nsPrefix, "message", new ConfBuf("Hello world from Java"))};

        } catch (Exception e) {
            throw new DpCallbackException("java-test failed", e);
        }
    }
}
