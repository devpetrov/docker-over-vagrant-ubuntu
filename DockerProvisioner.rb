class DockerProvisioner

    @config

    class << self
        def setup(config)
            @config = config
        end

        def lookForDocker(folder)
            if File.exists?(File.expand_path(folder[:from] + '/Dockerfile')) then
                false != folder[:docker] && self.addProvisioner(folder[:to], folder[:docker])
            end
        end

        def addProvisioner(path, options = {})
            options ||= {}

            options['imageName'] ||= path.tr('/', '-').gsub!(/^-/, '')

            options['bindMountSyncedFolder'] ||= [true]
            options['build'] ||= [true]
            options['run'] ||= [true]

            @config.vm.provision "docker", run: "always" do |d|
                if should('build', options) then
                    d.build_image path,
                        args: "-t #{options['imageName']}".concat(' ', getArgs('build', options))
                end

                if should('run', options) then
                    runArgs = getArgs('run', options)
                    
                    if should('bindMountSyncedFolder', options) then
                        mountPath = options['bindMountSyncedFolder'][1]
                        mountPath ||= path
                        
                        runArgs.concat(' ', "-v #{path}:#{mountPath}")
                    end

                    d.run options['imageName'],
                        args: runArgs
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