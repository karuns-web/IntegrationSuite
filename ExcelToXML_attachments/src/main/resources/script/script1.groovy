import com.sap.gateway.ip.core.customdev.util.Message
import com.equalize.cpi.converter.FormatConversionBean
 
def Message processData(Message message) {
 
def fcb = new FormatConversionBean(message.exchange, message.getProperties())
def output = fcb.convert()
message.setBody(output)
return message
}