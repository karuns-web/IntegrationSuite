import com.sap.gateway.ip.core.customdev.util.Message
import groovy.xml.MarkupBuilder
import groovy.xml.XmlUtil


def Message processData(Message message) {

    String body = message.getBody(String)

    if (body == null || body.trim().isEmpty()) {
        throw new IllegalArgumentException("Input file is empty")
    }


    /*
     * ============================================================
     * HELPERS
     * ============================================================
     */

    def getField = { String s, int start, int length ->

        if (s == null) {
            return ""
        }

        if (start >= s.length()) {
            return ""
        }

        int end = Math.min(start + length, s.length())

        return s.substring(start, end).trim()
    }


    def padRight = { String s, int length ->

        if (s == null) {
            s = ""
        }

        if (s.length() >= length) {
            return s.substring(0, length)
        }

        return s + (" " * (length - s.length()))
    }


    /*
     * ============================================================
     * INPUT LINES
     * ============================================================
     */

    List<String> lines =
            body.replace("\r", "")
                .split("\n", -1)
                .toList()


    /*
     * ============================================================
     * XML
     * ============================================================
     */

    StringWriter writer = new StringWriter()

    MarkupBuilder xml = new MarkupBuilder(writer)

    xml.setDoubleQuotes(true)


    xml.SAVES {


        /*
         * ========================================================
         * PROCESS EVERY RECORD
         * ========================================================
         */

        lines.eachWithIndex { String line, int lineNumber ->

            if (line == null || line.length() == 0) {
                return
            }


            String recordType = line.substring(0, 1)


            /*
             * ====================================================
             * RECORD 0
             * ====================================================
             */

            if (recordType == "0") {

                Record0 {

                    LineNumber(lineNumber)

                    RecordType("0")

                    /*
                     * Complete Record 0 data
                     */

                    HeaderData(
                            line.substring(1)
                    )
                }

                return
            }


            /*
             * ====================================================
             * RECORD 11 - CONUS VENDOR
             * ====================================================
             */

            if (line.startsWith("11")) {

                Record11 {

                    LineNumber(lineNumber)

                    RecordType("11")

                    Vendor_Id(
                            getField(line, 2, 15)
                    )

                    CAGECode(
                            getField(line, 17, 5)
                    )

                    VendorData(
                            getField(line, 22, 186)
                    )

                    /*
                     * If source contains additional data,
                     * don't lose it.
                     */

                    if (line.length() > 208) {

                        AdditionalData(
                                line.substring(208)
                        )
                    }
                }

                return
            }


            /*
             * ====================================================
             * RECORD 13 - OCONUS / EUROPE VENDOR
             * ====================================================
             */

            if (line.startsWith("13")) {

                Record13 {

                    LineNumber(lineNumber)

                    RecordType("13")

                    Vendor_Id(
                            getField(line, 2, 15)
                    )

                    CAGECode(
                            getField(line, 17, 5)
                    )

                    VendorData(
                            getField(line, 22, 186)
                    )

                    /*
                     * Europe/OCONUS records can have additional
                     * bank/address information after the standard
                     * portion.
                     */

                    if (line.length() > 208) {

                        AdditionalData(
                                line.substring(208)
                        )
                    }
                }

                return
            }


            /*
             * ====================================================
             * RECORD 2
             * ====================================================
             */

            if (recordType == "2") {

                Record2 {

                    LineNumber(lineNumber)

                    RecordType("2")


                    /*
                     * Vendor ID
                     */

                    Vendor_Id(
                            getField(line, 1, 15)
                    )


                    /*
                     * The actual source files supplied contain
                     * 267+ characters for Record 2.
                     *
                     * Therefore preserve the complete address
                     * portion instead of silently truncating it.
                     *
                     * Known logical positions:
                     */

                    Pay_Adr_His_1(
                            getField(line, 16, 27)
                    )

                    Pay_Adr_His_2(
                            getField(line, 43, 27)
                    )

                    Pay_Adr_His_3(
                            getField(line, 70, 20)
                    )

                    Pay_Adr_His_4(
                            getField(line, 90, 2)
                    )

                    Pay_Adr_His_5(
                            getField(line, 92, 12)
                    )


                    DOPS_Addr_1(
                            getField(line, 104, 40)
                    )

                    DOPS_Addr_2(
                            getField(line, 144, 40)
                    )

                    DOPS_Addr_3(
                            getField(line, 184, 40)
                    )

                    DOPS_Addr_4(
                            getField(line, 224, 40)
                    )

                    DOPS_Addr_5(
                            getField(line, 264, 20)
                    )


                    /*
                     * Anything beyond the supplied physical
                     * Record 2 data is retained here.
                     */

                    if (line.length() > 284) {

                        Additional_Record2_Data(
                                line.substring(284)
                        )
                    }
                }

                return
            }


            /*
             * ====================================================
             * RECORD 4
             * ====================================================
             *
             * First 29 characters:
             *
             * 1       Record type
             * 2-16    Vendor ID
             * 17-22   Office ID
             * 23-29   PIIN
             *
             * Complete PIIN:
             *
             * Office ID (6)
             * +
             * PIIN (7)
             *
             * = 13 characters
             */

            if (recordType == "4") {

                if (line.length() < 29) {

                    throw new IllegalArgumentException(
                            "Record 4 at line " +
                            lineNumber +
                            " is shorter than 29 characters"
                    )
                }


                String vendorId =
                        getField(line, 1, 15)

                String officeId =
                        getField(line, 16, 6)

                String piin7 =
                        getField(line, 22, 7)

                String piin =
                        officeId + piin7


                /*
                 * Transaction portion.
                 */

                String transaction =
                        line.substring(29)


                /*
                 * =================================================
                 * IMPORTANT
                 *
                 * Record 4 is fixed length, but some CONUS records
                 * do not contain a '+' between transaction field 1
                 * and field 2.
                 *
                 * Therefore parse according to FIXED LENGTHS.
                 *
                 * Standard CONUS/OCONUS transaction fields:
                 *
                 * 31
                 * 14
                 * 14
                 * 14
                 * 14
                 * 14
                 * 14
                 * 13
                 * 12
                 * 12
                 * 14
                 * 32
                 * 51
                 *
                 * Europe contains additional fields.
                 * =================================================
                 */

                int[] standardLengths = [

                        31,
                        14,
                        14,
                        14,
                        14,
                        14,
                        14,
                        13,
                        12,
                        12,
                        14,
                        32,
                        51,
                        8
                ]


                /*
                 * Europe additional fields observed in the
                 * supplied file:
                 *
                 * 14
                 * 14
                 * 14
                 * 14
                 * 14
                 * 12
                 * 14
                 */

                int[] europeAdditionalLengths = [

                        14,
                        14,
                        14,
                        14,
                        14,
                        12,
                        14
                ]


                /*
                 * Parse fixed fields while allowing optional '+'
                 * separator after each field.
                 */

                List<String> parsedFields = []

                int position = 0


                /*
                 * First 13/14 standard fields.
                 */

                standardLengths.each { int fieldLength ->

                    if (position >= transaction.length()) {

                        return
                    }


                    int end =
                            Math.min(
                                    position + fieldLength,
                                    transaction.length()
                            )


                    String value =
                            transaction.substring(
                                    position,
                                    end
                            )


                    parsedFields << value

                    position = end


                    /*
                     * '+' is a separator, not part of field.
                     *
                     * Some source records omit the separator,
                     * so only consume it when actually present.
                     */

                    if (position < transaction.length() &&
                        transaction.charAt(position) == '+') {

                        position++
                    }
                }


                /*
                 * Remaining fields for Europe/OCONUS.
                 */

                europeAdditionalLengths.each { int fieldLength ->

                    if (position >= transaction.length()) {

                        return
                    }


                    int end =
                            Math.min(
                                    position + fieldLength,
                                    transaction.length()
                            )


                    String value =
                            transaction.substring(
                                    position,
                                    end
                            )


                    parsedFields << value

                    position = end


                    if (position < transaction.length() &&
                        transaction.charAt(position) == '+') {

                        position++
                    }
                }


                /*
                 * =================================================
                 * XML
                 * =================================================
                 */

                Record4 {

                    LineNumber(lineNumber)

                    RecordType("4")

                    Vendor_Id(vendorId)

                    Office_ID(officeId)

                    PIIN_7(piin7)

                    /*
                     * Required 13-character PIIN
                     */

                    PIIN(piin)


                    /*
                     * Every parsed transaction field.
                     */

                    parsedFields.eachWithIndex {
                            String value,
                            int fieldIndex ->

                        String elementName =
                                String.format(
                                        "Transaction_Field_%02d",
                                        fieldIndex + 1
                                )

                        /*
                         * Groovy MarkupBuilder dynamic element
                         */

                        xml."${elementName}"(
                                value
                        )
                    }


                    /*
                     * If anything remains after the known fields,
                     * preserve it rather than dropping data.
                     */

                    if (position < transaction.length()) {

                        Remaining_Transaction_Data(
                                transaction.substring(position)
                        )
                    }
                }

                return
            }


            /*
             * ====================================================
             * ANY OTHER RECORD TYPE
             *
             * Nothing is discarded.
             * ====================================================
             */

            OtherRecord {

                LineNumber(lineNumber)

                RecordType(recordType)

                RecordData(
                        line.substring(1)
                )
            }
        }
    }


    /*
     * ============================================================
     * SERIALIZE
     * ============================================================
     */

    String output =
            XmlUtil.serialize(
                    writer.toString()
            )


    /*
     * ============================================================
     * SET CPI BODY
     * ============================================================
     */

    message.setBody(output)

    return message
}