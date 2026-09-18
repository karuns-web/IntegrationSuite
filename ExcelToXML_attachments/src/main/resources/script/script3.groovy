package script
import com.sap.gateway.ip.core.customdev.util.Message;

def Message processData(Message message) {
  if (message!=null && message.getBody()!=null ) {

        def body_bytes = message.getBody(byte[].class);
       // save value to the attach file in message log
        def messageLog = messageLogFactory.getMessageLog(message);
        messageLog.addAttachmentAsString("XML_Body", new String(body_bytes) , "text/plain");
        }

    return message;
}