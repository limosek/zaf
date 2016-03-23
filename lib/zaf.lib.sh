# Update repo
zaf_update_repo() {
	cd ${ZAF_REPO_DIR} && git pull
}

# List installed plugins
zaf_list_installed_plugins() {
	cd ${ZAF_PLUGINS_DIR}; ls -d 
}

# Install plugin. 
# Parameter is url, directory or plugin name (will be searched in default plugin dir)
zaf_install_plugin() {
	a
}
