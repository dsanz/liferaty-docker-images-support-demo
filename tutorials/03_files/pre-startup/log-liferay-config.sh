echo
echo "** Liferay configuration report **"
echo "=================================="

echo "Environment variables"
echo "---------------------"

for scope in LIFERAY JAVA; do
    echo "→  $scope"
    env | grep $scope
    echo
done

echo "properties files"
echo "----------------"
for files in $LIFERAY_HOME/portal*.properties $LIFERAY_HOME/tomcat/webapps/ROOT/WEB-INF/classes/system*.properties; do
    for file in $(ls $files 2>/dev/null); do
        echo
        echo "→  $file"
        cat $file
    done
done
echo

echo "OSGi configuration files"
echo "------------------------"
tree $LIFERAY_HOME/osgi/configs/
for config in $(ls $LIFERAY_HOME/osgi/configs/); do
    echo "→  $config:"; cat $LIFERAY_HOME/osgi/configs/$config;
    echo; echo;
done

echo "Patching tool"
echo "-------------"
$LIFERAY_HOME/patching-tool/patching-tool.sh info
