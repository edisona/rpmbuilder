
```
USAGE:

     smart-rpmbuilder.sh <filepath> [--release]

OPTIONS:
     <filepath> - Full path to rpm.properties file, it could be either local file path or svn url
     --release  - If provided, will push the rpm to maven release repo ($maven_release_repo_url);
                  the rpm will be pushed to maven snapshot repo ($maven_snapshot_repo_url)
                  whether --release was provided or not

MORE INFORMATION
----------------

    The script expects a property file with information about the rpm such as name, version, files, target location, etc..
You will also need to have environment variable 'svn_username' and 'svn_password' if you are passing svn url path to rpm.property file
And 'MAVEN_HOME' if your 'mvn' is not in PATH.
Here is an example property file..

==================== rpm.properties ====================
  rpm_name=my_app
  rpm_version=1.0
  rpm_release=$(date +%s)
  rpm_summary=${rpm_name}
  rpm_install_dir=/projects/my_app/webapps
  files=src/my_application.properties,log4j.xml
  maven_skip=true
========================================================

Here is the directory structure of the above rpm.properties and its related files
    |  
    |-- log4j.xml
    |-- src  
    |    |  
    |    |-- my_application.properties
    |-- rpm.properties

PROPERTY DESCRIPTION
--------------------

 rpm_name                     - Application name
 rpm_version                  - Application version
 rpm_release                  - Application rlease number
 rpm_summary                  - Application description for the rpm
 rpm_install_dir              - The target directory where the files inside rpm will be placed. Must be full path. This is an Array, and 
                                if there are more than one target directory, declare each one like this:
                                   rpm_install_dir[0]=xxx
                                   rpm_install_dir[1]=xxx
                                rpm_install_dir[x] with no files[x] can be used to create empty directory
 files                        - Comma separated file list with the path relative to the rpm property file. This is also an Array
                                like 'rpm_install_dir'. File list for each target directory can be declared like this:
                                   files[0]=file1.txt,file2.txt
                                   files[1]=file3.txt
                                files[0] will goes into rpm_install_dir[0], etc..
                                Can provide directory as well. If it's a directory, all files/directories under it will be included
                                in the rpm (the directory itself will not be included)
 rpm_own_dir                  - A 'true/false' flag array to specify whether the rpm_install_dir[x] should be owned by the rpm or not. Default is 'false'
 attributes                   - File/Directory attribute array. Format - (attribute value,owner name,group name). E.g:
                              -    attributes[1]=755,java,root
                              - Each item in the array represents the corresponding item from 'rpm_install_dir' array
 rpm_install_post_script      - Shell script that will be executed during the %post section of rpm installation. 
                                Need to wrap the content in double quote. It is recommended to use 'rpm_install_post_script_file' instead 
                                if you have more than one line of script For example, 
                                     rpm_install_post_script_file="echo hi"
 rpm_install_post_script_file - The path to the shell script file which content will be executed during the %post section of rpm installation.
                                Like any other file references, the path need to be relative to the rpm properties file
 rpm_install_pre_script       - Similar to 'rpm_install_post_script' except that this will goes into %pre section
 rpm_install_pre_script_file  - Similar to 'rpm_install_post_script_file' except that this will goes into %pre section
 maven_skip                   - Flag to specify whether the output rpm should be pushed to maven repository (nexus)
                                if '--release' is provided, will push the rpm to maven release repository
 maven_groupId                - Maven groupId value of the application
 maven_artifactId             - Maven artifactId value of the application
 MAVEN_HOME                   - Environment variable for maven home directory
 svn_username                 - Environment variable for SVN login username
 svn_password                 - Environment variable for SVN login password
 symlink                      - An array property to create symbolic link(s). The format is <dir,name,target>
                                    symlink[0]=/usr/bin/,myapp,/opt/app/myapp
 symlink_attributes            - An array property to specify file attribute for the corresponding symlink
                                    symlink_attributes[0]=755,java,java
 rpm_username                 - Default 'tomcat'
 rpm_groupname                - Default 'tomcat'
 rpm_filemode                 - Default 644
```