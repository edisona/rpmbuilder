#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "$0" )" && pwd )"
SCRIPT_NAME=$(basename $0)
OLDIFS=$IFS
IFS=,

rpm_filemode=755
rpm_username=tomcat
rpm_groupname=tomcat
rpm_summary=EMPTY
rpm_license="CopyRight 2011"
rpm_group=Applications
rpm_packager="Custom RPM Builder"
rpm_install_post_script_file=

maven_snapshot_repo_id=${maven_snapshot_repo_id:=}
maven_snapshot_repo_url=${maven_snapshot_repo_url:=}

maven_release_repo_id=${maven_release_repo_id:=}
maven_release_repo_url=${maven_release_repo_url:=}

maven_package_type=rpm
maven_classifier=rpm
maven_skip=${maven_skip:=true}

svn_username=${svn_username:=}
svn_password=${svn_password:=}



function usage() {
	echo "";
	echo "USAGE:";
	echo "";
	echo "     $SCRIPT_NAME <filepath> [--release]";
	echo "";
	echo "OPTIONS:";
	echo "     <filepath> - Full path to rpm.properties file, it could be either local file path or svn url";
	echo "     --release  - If provided, will push the rpm to maven release repo (\$maven_release_repo_url);";
	echo "                  the rpm will be pushed to maven snapshot repo (\$maven_snapshot_repo_url)";
	echo "                  whether --release was provided or not";
	echo "";
	echo "MORE INFORMATION";
	echo "----------------";
	echo "";
	echo "    The script expects a property file with information about the rpm such as name, version, files, target location, etc..";
	echo "You will also need to have environment variable 'svn_username' and 'svn_password' if you are passing svn url path to rpm.property file";
	echo "And 'MAVEN_HOME' if your 'mvn' is not in PATH.";  
	echo "Here is an example property file..";
	echo "";
	echo "==================== rpm.properties ====================";
	echo "  rpm_name=my_app";
	echo "  rpm_version=1.0";
	echo "  rpm_release=\$(date +%s)";
	echo "  rpm_summary=\${rpm_name}";
	echo "  rpm_install_dir=/projects/my_app/webapps";
	echo "  files=src/my_application.properties,log4j.xml";
	echo "  maven_skip=true";
	echo "========================================================";
	echo "";
	echo "Here is the directory structure of the above rpm.properties and its related files";
	echo "    |  ";
	echo "    |-- log4j.xml";
	echo "    |-- src  ";
	echo "    |    |  ";
	echo "    |    |-- my_application.properties";
	echo "    |-- rpm.properties";
	echo "";
	echo "PROPERTY DESCRIPTION";
	echo "--------------------";
	echo "";
	echo " rpm_name                     - Application name";
	echo " rpm_version                  - Application version";
	echo " rpm_release                  - Application rlease number";
	echo " rpm_summary                  - Application description for the rpm";
	echo " rpm_install_dir              - The target directory where the files inside rpm will be placed. Must be full path. This is an Array, and "; 
	echo "                                if there are more than one target directory, declare each one like this:";
	echo "                                   rpm_install_dir[0]=xxx";
	echo "                                   rpm_install_dir[1]=xxx";
	echo "                                rpm_install_dir[x] with no files[x] can be used to create empty directory";
	echo " files                        - Comma separated file list with the path relative to the rpm property file. This is also an Array"; 
	echo "                                like 'rpm_install_dir'. File list for each target directory can be declared like this:";
	echo "                                   files[0]=file1.txt,file2.txt";
	echo "                                   files[1]=file3.txt";
	echo "                                files[0] will goes into rpm_install_dir[0], etc..";
	echo "                                Can provide directory as well. If it's a directory, all files/directories under it will be included";
	echo "                                in the rpm (the directory itself will not be included)";
	echo " rpm_own_dir                  - A 'true/false' flag array to specify whether the rpm_install_dir[x] should be owned by the rpm or not. Default is 'false'";
	echo " attributes                   - File/Directory attribute array. Format - (attribute value,owner name,group name). E.g:";
	echo "                              -    attributes[1]=755,java,root";
	echo "                              - Each item in the array represents the corresponding item from 'rpm_install_dir' array";
	echo " rpm_install_post_script      - Shell script that will be executed during the %post section of rpm installation. ";
	echo "                                Need to wrap the content in double quote. It is recommended to use 'rpm_install_post_script_file' instead ";
	echo "                                if you have more than one line of script For example, ";
	echo "                                     rpm_install_post_script_file=\"echo hi\"";
	echo " rpm_install_post_script_file - The path to the shell script file which content will be executed during the %post section of rpm installation.";
	echo "                                Like any other file references, the path need to be relative to the rpm properties file";
	echo " rpm_install_pre_script       - Similar to 'rpm_install_post_script' except that this will goes into %pre section";
	echo " rpm_install_pre_script_file  - Similar to 'rpm_install_post_script_file' except that this will goes into %pre section";
	echo " maven_skip                   - Flag to specify whether the output rpm should be pushed to maven repository (nexus)";
	echo "                                if '--release' is provided, will push the rpm to maven release repository";
	echo " maven_groupId                - Maven groupId value of the application";
	echo " maven_artifactId             - Maven artifactId value of the application";
	echo " MAVEN_HOME                   - Environment variable for maven home directory";
	echo " svn_username                 - Environment variable for SVN login username";
	echo " svn_password                 - Environment variable for SVN login password";
	echo " symlink                      - An array property to create symbolic link(s). The format is <dir,name,target>";
	echo "                                    symlink[0]=/usr/bin/,myapp,/opt/app/myapp";
	echo " symlink_attributes            - An array property to specify file attribute for the corresponding symlink";
	echo "                                    symlink_attributes[0]=755,java,java"
	echo " rpm_username                 - Default 'tomcat'";
	echo " rpm_groupname                - Default 'tomcat'";
	echo " rpm_filemode                 - Default 644";
	echo " rpm_requires                 - Capability and version that this package depends on";
	echo " rpm_provides                 - Capability that this package provides";
	echo "";
}

function validate_environment() {
	if [ "$maven_skip" != "true" ]; then
		# if MAVEN_HOME is declared, use it
		if [ -d "$MAVEN_HOME" -a -x "$MAVEN_HOME/bin/mvn" ]; then
			MVN_CMD=$MAVEN_HOME/bin/mvn
		else 
			if [ "$(which mvn)" == "" ]; then
				echo "mvn not in path!"; exit 1;
			else
				MVN_CMD="$(which mvn)"
			fi
		fi		
	fi
	
	if [ "$(which svn)" == "" ]; then
		echo "svn not in path!"; exit 1;
	fi
	if [ "$(which rpmbuild)" == "" ]; then
		echo "rpmbuild not in path!"; exit 1;
	fi
}

function checkval() {
	if [[ "$1" == "" ]]; then
		echo "Error: $2" >&2; exit 1;
	fi
}

function printmsg() {
	echo "$1";
}

function validate_properties() {
	checkval "$rpm_name" "rpm_name cannot be empty"
	checkval "$rpm_version" "rpm_version cannot be empty" 
	checkval "$rpm_release" "rpm_release cannot be empty" 
	checkval "$rpm_summary" "rpm_summary cannot be empty" 
	
	if [ "$maven_skip" != "true" ]; then
		checkval "$maven_groupId" "maven_groupId cannot be empty"
		checkval "$maven_artifactId" "maven_artifactId cannot be empty"
		checkval "$maven_snapshot_repo_id" "maven_snapshot_repo_id cannot be empty"
		checkval "$maven_snapshot_repo_url" "maven_snapshot_repo_url cannot be empty"
	fi

	checkval "$rpm_username" "rpm_username cannot be empty"
	checkval "$rpm_groupname" "rpm_groupname cannot be empty"
	
	checkval "$rpm_install_dir" "rpm_install_dir cannot be empty"
	
	for i in $(seq -s, 0 $((${#rpm_install_dir[@]} - 1))); do
		checkval "${rpm_install_dir[$i]}" "rpm_install_dir[$i] cannot be empty";
	done
	
	if [ "$symlink" != "" ]; then
		for i in ${!symlink[@]}; do
			local link=(${symlink[$i]})
			checkval "${link[0]}" "symlink[$i] format is not correct"
			checkval "${link[1]}" "symlink[$i] format is not correct"
			checkval "${link[2]}" "symlink[$i] format is not correct"
		done
	fi
}

function create_rpm_layout() {
	echo "Creating RPM directories..";
	RPM_ROOT=${TMP_DIR}/rpm/${rpm_name}
	RPM_OUTPUT_ROOT=${RPM_ROOT}/RPMS
	RPM_TMP_BUILDROOT=${RPM_ROOT}/tmp-buildroot
	RPM_BUILDROOT=${RPM_ROOT}/buildroot
	RPM_SPEC=${RPM_ROOT}/SPECS

	mkdir -p ${RPM_ROOT}/{BUILD,SOURCES,SRPMS}
	mkdir -p ${RPM_OUTPUT_ROOT}
	mkdir -p ${RPM_TMP_BUILDROOT}
	mkdir -p ${RPM_BUILDROOT}
	mkdir -p ${RPM_SPEC}
	
	for i in $(seq -s, 0 $((${#rpm_install_dir[@]} - 1))); do
		mkdir -p ${RPM_TMP_BUILDROOT}/${rpm_install_dir[$i]}
	done
}

function cleanup_svnpath() {
	local svn_path=$1
	while [[ $svn_path == *..* ]]; do
		svn_path=$(echo $svn_path | sed -e 's/\/\w*\/\.\.//g')
	done
	echo $svn_path
}

function prepare_files_for_rpm() {
	echo "Copying files for RPM..";
	# Copy required files
	for i in $(seq -s, 0 $((${#rpm_install_dir[@]} - 1))); do
		for f in ${files[$i]}; do
			if [ "$LOCAL_FILE" == "true" ]; then
				if [ -f "${PROP_DIR}/$f" ]; then
					rsync -a --exclude '.svn' ${PROP_DIR}/$f ${RPM_TMP_BUILDROOT}/${rpm_install_dir[$i]};
				elif [ -d "${PROP_DIR}/$f" ]; then
					rsync -a --exclude '.svn' ${PROP_DIR}/$f/* ${RPM_TMP_BUILDROOT}/${rpm_install_dir[$i]};
				else
					echo "Error: file/folder (${PROP_DIR}/$f) not found"; exit 1;
				fi
			else 
				echo "Exporting $SVN_ROOT/$f";
				mkdir -p $(dirname ${TMP_SRC_DIR}/$f)
				local svn_path=$(cleanup_svnpath $SVN_ROOT/$f)
				local checkout_path=${TMP_SRC_DIR}/$(basename $f)
				svn export $svn_path $checkout_path --username=$svn_username --password=$svn_password > /dev/null
	
				if [ -f $checkout_path ]; then
					rsync -a --exclude '.svn' $checkout_path ${RPM_TMP_BUILDROOT}/${rpm_install_dir[$i]};
				else
					rsync -a --exclude '.svn' $checkout_path/* ${RPM_TMP_BUILDROOT}/${rpm_install_dir[$i]};
				fi
			fi
		done
	done
	
	if [ "$rpm_install_pre_script_file" != "" ]; then
		if [ "$LOCAL_FILE" == "true" ]; then
			rpm_install_pre_script_file=${PROP_DIR}/${rpm_install_pre_script_file}
		else
			local svn_path=$(cleanup_svnpath $SVN_ROOT/$rpm_install_pre_script_file)
			local checkout_path=${TMP_SRC_DIR}/$(basename $rpm_install_pre_script_file)
			svn export $svn_path $checkout_path --username=$svn_username --password=$svn_password > /dev/null
			rpm_install_pre_script_file=${checkout_path}
		fi
	fi
	
	if [ "$rpm_install_post_script_file" != "" ]; then
		if [ "$LOCAL_FILE" == "true" ]; then
			rpm_install_post_script_file=${PROP_DIR}/${rpm_install_post_script_file}
		else
			local svn_path=$(cleanup_svnpath $SVN_ROOT/$rpm_install_post_script_file)
			local checkout_path=${TMP_SRC_DIR}/$(basename $rpm_install_post_script_file)
			svn export $svn_path $checkout_path --username=$svn_username --password=$svn_password > /dev/null
			rpm_install_post_script_file=${checkout_path}
		fi
	fi

	# Handle symbolic link
	if [ "$symlink" != "" ]; then
		for i in ${!symlink[@]}; do
			local link=(${symlink[$i]})
			
			local link_dir=${link[0]};
			local link_name=${link[1]};
			local link_target=${link[2]};
			
			if [ ! -d "$RPM_TMP_BUILDROOT/$link_dir}" ]; then
				mkdir -p $RPM_TMP_BUILDROOT/$link_dir;
			fi
			
			(cd $RPM_TMP_BUILDROOT/$link_dir; ln -sf $link_target $link_name);
			symlink[$i]="$link_dir/$link_name";
		done  
	fi
}

function create_spec_file() {
	echo "Generating SPEC file";

	RPM_SPEC_FILE=$RPM_SPEC/$rpm_name.spec
	echo "%define _unpackaged_files_terminate_build 0" > $RPM_SPEC_FILE
	
	echo "Name: ${rpm_name}" >> $RPM_SPEC_FILE
	echo "Version: ${rpm_version}" >> $RPM_SPEC_FILE
	echo "Release: ${rpm_release}" >> $RPM_SPEC_FILE
	echo "Summary: ${rpm_summary}" >> $RPM_SPEC_FILE
	echo "License: ${rpm_license}" >> $RPM_SPEC_FILE
	echo "Group: ${rpm_group}" >> $RPM_SPEC_FILE
	echo "Packager: ${rpm_packager}" >> $RPM_SPEC_FILE
	echo "autoprov: yes" >> $RPM_SPEC_FILE
	echo "autoreq: yes" >> $RPM_SPEC_FILE
	echo "BuildRoot: $RPM_BUILDROOT" >> $RPM_SPEC_FILE
	if [[ "${rpm_requires}" != "" ]]; then
		echo "Requires: ${rpm_requires}" >> $RPM_SPEC_FILE
	fi
	if [[ "${rpm_provides}" != "" ]]; then
		echo "Provides: ${rpm_provides}" >> $RPM_SPEC_FILE
	fi
	echo "" >> $RPM_SPEC_FILE
	
	echo "%description" >> $RPM_SPEC_FILE
	echo "" >> $RPM_SPEC_FILE
	
	echo "%install" >> $RPM_SPEC_FILE
	echo "" >> $RPM_SPEC_FILE
	echo "if [ -e $RPM_BUILDROOT ]; then" >> $RPM_SPEC_FILE
	echo "  mv $RPM_TMP_BUILDROOT/* $RPM_BUILDROOT" >> $RPM_SPEC_FILE
	echo "else" >> $RPM_SPEC_FILE
	echo "  mv $RPM_TMP_BUILDROOT $RPM_BUILDROOT" >> $RPM_SPEC_FILE
	echo "fi" >> $RPM_SPEC_FILE
	echo "" >> $RPM_SPEC_FILE
	
	echo "%files" >> $RPM_SPEC_FILE
	echo "" >> $RPM_SPEC_FILE
	
	echo "%defattr(${rpm_filemode},${rpm_username},${rpm_groupname})" >> $RPM_SPEC_FILE
	
	for i in $(seq -s, 0 $((${#rpm_install_dir[@]} - 1))); do
		if [ "${files[$i]}" == "" ]; then
			echo -n " %dir" >> $RPM_SPEC_FILE;
			if [ "${attributes[$i]}" != "" ]; then
				echo -n " %attr(${attributes[$i]}) " >> $RPM_SPEC_FILE;
			fi
			echo " ${rpm_install_dir[$i]}" >> $RPM_SPEC_FILE
		else
			if [ "${rpm_own_dir[$i]}" == "true" ]; then
				if [ "${attributes[$i]}" != "" ]; then
					echo -n " %attr(${attributes[$i]}) " >> $RPM_SPEC_FILE;
				fi
				echo " ${rpm_install_dir[$i]}" >> $RPM_SPEC_FILE
			else
				for f in ${files[$i]}; do
					if [ "${attributes[$i]}" != "" ]; then
						echo -n " %attr(${attributes[$i]}) " >> $RPM_SPEC_FILE;
					fi
					if [ "$LOCAL_FILE" == "true" ]; then
						f=${PROP_DIR}/$f;
					else
						f=${TMP_SRC_DIR}/$(basename $f);
					fi
		
					if [ -f $f ]; then
						echo " ${rpm_install_dir[$i]}/$(basename $f)" >> $RPM_SPEC_FILE
					elif [ -d $f ]; then
						IFS=$OLDIFS
						#for sf in `find $f/* | grep -v '.svn'`; do
						# Include everything from $f
						for sf in `ls $f/`; do
							echo " ${rpm_install_dir[$i]}/$(echo "$sf" | awk '{gsub(x,"")}; 1' x="$f/")" >> $RPM_SPEC_FILE
						done
						IFS=,
					else
						echo "ERROR: The input file ($f) is neither file nor directory!";
						exit 1;
					fi
				done
			fi
		fi
	done
	
	for i in ${!symlink[@]}; do
		if [ "${symlink_attributes[$i]}" != "" ]; then
			echo -n " %attr(${symlink_attributes[$i]}) " >> $RPM_SPEC_FILE;
		fi
		echo " ${symlink[$i]}" >> $RPM_SPEC_FILE;
	done
	
	echo "" >> $RPM_SPEC_FILE
	
	echo "%pre" >> $RPM_SPEC_FILE;
	
	if [ "$rpm_install_pre_script" != "" ]; then
		echo "$rpm_install_pre_script" >> $RPM_SPEC_FILE;
	fi
	
	if [ "$rpm_install_pre_script_file" != "" ]; then
		cat ${rpm_install_pre_script_file} >> $RPM_SPEC_FILE;
	fi
	
	echo "%post" >> $RPM_SPEC_FILE;
	
	if [ "$rpm_install_post_script" != "" ]; then
		echo "$rpm_install_post_script" >> $RPM_SPEC_FILE;
	fi
	
	if [ "$rpm_install_post_script_file" != "" ]; then
		cat ${rpm_install_post_script_file} >> $RPM_SPEC_FILE;
	fi
	
	echo "SPEC file created - {{$RPM_SPEC_FILE}}";
}

function create_rpm() {
	echo "Building RPM package.."
	rpmbuild -bb --buildroot $RPM_BUILDROOT --define "_topdir $RPM_ROOT" --target noarch-pc-linux $RPM_SPEC_FILE
	RPM_FILE=${RPM_OUTPUT_ROOT}/noarch/${rpm_name}-${rpm_version}-${rpm_release}.noarch.rpm
	if [ ! -f "$RPM_FILE" ]; then
		echo "Failed to create RPM file"; exit 1;
	else 
		echo "RPM created - {{$RPM_FILE}}";
	fi
}

function push_to_maven_repo() {
	echo "Pushing RPM to Maven repo";
	maven_package_release_version=${rpm_version}.${rpm_release}
	maven_package_snapshot_version=${rpm_version}.${rpm_release}-SNAPSHOT
	retries=3

	# push to maven snapshot repo
	echo "$MVN_CMD deploy:deploy-file -Dfile=${RPM_FILE} -DrepositoryId=${maven_snapshot_repo_id} -Durl=${maven_snapshot_repo_url} -DgroupId=${maven_groupId} -DartifactId=${maven_artifactId} -Dpackaging=${maven_package_type} -Dversion=${maven_package_snapshot_version} -Dclassifier=${maven_classifier}";
	$MVN_CMD deploy:deploy-file -Dfile=${RPM_FILE} -DrepositoryId=${maven_snapshot_repo_id} -Durl=${maven_snapshot_repo_url} -DgroupId=${maven_groupId} -DartifactId=${maven_artifactId} -Dpackaging=${maven_package_type} -Dversion=${maven_package_snapshot_version} -Dclassifier=${maven_classifier}
	
	if [ "$1" == "--release" ]; then
		echo "$MVN_CMD org.apache.maven.plugins:maven-deploy-plugin:2.7:deploy-file -DretryFailedDeploymentCount=${retries} -Dfile=${RPM_FILE} -DrepositoryId=${maven_release_repo_id} -Durl=${maven_release_repo_url} -DgroupId=${maven_groupId} -DartifactId=${maven_artifactId} -Dpackaging=${maven_package_type} -Dversion=${maven_package_release_version} -Dclassifier=${maven_classifier}";
		$MVN_CMD org.apache.maven.plugins:maven-deploy-plugin:2.7:deploy-file -DretryFailedDeploymentCount=${retries} -Dfile=${RPM_FILE} -DrepositoryId=${maven_release_repo_id} -Durl=${maven_release_repo_url} -DgroupId=${maven_groupId} -DartifactId=${maven_artifactId} -Dpackaging=${maven_package_type} -Dversion=${maven_package_release_version} -Dclassifier=${maven_classifier}
	fi
}

function main() {
	if [[ -z "$1" ]]; then
		usage; exit 0;
	else
		PROP_FILE=$1
	fi
	
	# copy property file
	if [[ "$PROP_FILE" =~ ^http: ]]; then
		checkval "$svn_username" "svn_username cannot be empty"
		checkval "$svn_password" "svn_password cannot be empty"
		LOCAL_FILE=false
		SVN_ROOT="$(dirname $PROP_FILE)"
		svn export $PROP_FILE /tmp/rpmbuild.properties --username=$svn_username --password=$svn_password  > /dev/null
		PROP_FILE=/tmp/rpmbuild.properties
	else
		LOCAL_FILE=true
	fi
	source $PROP_FILE
	
	validate_environment
	
	# Allow user to set TMP_DIR, will not do validation
	if [ "$TMP_DIR" == "" ]; then
		TMP_DIR=$(mktemp -d)
	else
		if [ -d "$TMP_DIR" ]; then
			rm -r $TMP_DIR/*;
		fi
	fi
	TMP_SRC_DIR=$TMP_DIR/src;
	echo "Using temp dir $TMP_DIR";
	mkdir -p $TMP_SRC_DIR;
	
	PROP_DIR="$( cd "$( dirname "$PROP_FILE" )" && pwd )"

	validate_properties
	create_rpm_layout
	prepare_files_for_rpm
	create_spec_file
	create_rpm

#	echo "RPM contents";
#	rpm -lqp $RPM_FILE
	
	if [ "$maven_skip" != "true" ]; then
		push_to_maven_repo "$2"
	else
		echo "Skipping maven deployment";
	fi

	#echo "Clean up temp directory";
	#rm -r ${TMP_DIR}
}

main $*
IFS=$OLDIFS
