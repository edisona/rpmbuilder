A script that I use to automate the rpm creation of all my projects as part of continuous integration and continuous delivery.

The script will help you generate SPEC file and create RPM for you; and also if you wish it can push the generated rpm file to your desired maven repository.

## Prerequisites ##

  * rpm-build (http://rpmfind.net/linux/RPM/rpm-build.html)
  * subversion (I'll make this one as optional in next version)

## Installation ##
Download the rpm and type:
```
# rpm -i -p smart-rpmbuilder-1.x.xxx.rpm 
```
After that you can access the script at:
```
# /opt/tools/smart-rpmbuilder.sh
```
