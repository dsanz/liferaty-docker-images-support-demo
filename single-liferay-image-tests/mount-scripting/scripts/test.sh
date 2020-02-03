function enable_ajp {
	local server_xml="server.xml"
	local tomcat_server_xml="/opt/liferay/tomcat/conf/$server_xml"
	local tmp_server_xml="/tmp/$server_xml"
	local tmp_server_xml_ajp="$tmp_server_xml.ajp-enabled"

	cp $tomcat_server_xml $tmp_server_xml

	cat $tmp_server_xml | sed -r 's:<!-- (<Connector port="8009"[^>]+>) -->:\1:' > $tmp_server_xml_ajp

	mv $tmp_server_xml_ajp $tomcat_server_xml
	rm $tmp_server_xml
}

enable_ajp
