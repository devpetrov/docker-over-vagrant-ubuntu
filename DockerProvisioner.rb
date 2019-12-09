class DockerProvisioner

    @config
    @outputLogger

    class << self
        def setup(config, outputLogger)
            @config = config
            @outputLogger = outputLogger
        end

        def lookForDocker(folder)
            return if false == folder[:docker]

            folder[:docker] ||= {}
            folder[:docker]['dockerfile'] ||= 'Dockerfile'
            localPath = folder[:from] + '/' + folder[:docker]['dockerfile']

            folder[:docker]['dockerfile'].prepend(folder[:to], '/')
            
            expandedPath = File.expand_path(localPath)

            if File.exists?(expandedPath) then
                self.addProvisioner(folder[:to], folder[:docker])
            else
                @outputLogger.log "Looked for \"#{expandedPath}\" but didn't found it. Docker provisioner will not be run for this synced folder.",
                    ProvisionOutputLogger::LOG_STDERR
            end
        end

        def addProvisioner(path, options = {})
            options ||= {}

            options['imageName'] ||= path.tr('/', '-').gsub!(/^-/, '')

            options['bindMountSyncedFolder'] ||= [true]
            options['build'] ||= [true]
            options['run'] ||= [true]
            options['env'] ||= {}

            @config.vm.provision "docker", run: "always" do |d|
                if should('build', options) then
                    buildArgs = getArgs('build', options)
                    buildArgs.concat(' -t ', options['imageName'])
                    buildArgs.concat(' -f ', options['dockerfile'])

                    d.build_image path,
                        args: buildArgs
                end

                if should('run', options) then
                    runArgs = getArgs('run', options)
                    
                    runArgs += ' --restart=on-failure' unless 
                        runArgs.downcase().include?('--restart') unless
                            runArgs.downcase().include?('--rm')
                    
                    if should('bindMountSyncedFolder', options) then
                        mountPath = options['bindMountSyncedFolder'][1]
                        mountPath ||= path
                        
                        runArgs.concat(' ', "-v #{path}:#{mountPath}")

                        runArgs.concat(' ', "--env \"BIND_MOUNT_PATH=#{mountPath}\"")

                        if (options['bindMountSyncedFolder'][2]) then
                            runArgs.concat(' ', "--env \"#{options['bindMountSyncedFolder'][2]}=#{mountPath}\"")
                            runArgs.concat(' ', "--env \"BIND_MOUNT_PATH_VAR_NAME=#{options['bindMountSyncedFolder'][2]}\"")
                        else
                            runArgs.concat(' ', "--env \"BIND_MOUNT_PATH_VAR_NAME=BIND_MOUNT_PATH\"")
                        end
                    end

                    options['env'].each do |name, value|
                        if value.nil? 
                            runArgs.concat(' ', "--env #{name}")
                        else
                            runArgs.concat(' ', "--env \"#{name}=#{value}\"")
                        end
                    end

                    d.run options['imageName'],
                        args: runArgs,
                        restart: 'no'
                end
            end
        end

        def should(command, options)
            options[command][0]
        end

        def getArgs(command, options)
            options[command][1..-1].join(' ')
        end
    end
end