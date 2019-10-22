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

            @config.vm.provision "docker", run: "always" do |d|
                if should('build', options, true) then
                    d.build_image path,
                        args: "-t #{options['imageName']}".concat(' ', getArgs('build', options))
                end

                if should('run', options, true) then
                    runArgs = getArgs('run', options)
                    
                    if should('bindMountSyncedFolder', options, true) then
                        mountPath = getArgs('bindMountSyncedFolder', options)

                        if mountPath.empty? then
                            mountPath = path
                        end

                        runArgs.concat(' ', "-v #{path}:#{mountPath}")
                    end

                    d.run options['imageName'],
                        args: runArgs
                end
            end
        end

        def should(command, options, default)
            if options.include?(command) then 
                options[command][0]
            else
                default
            end
        end

        def getArgs(command, options)
            if (options[command] && nil != options[command].at(1)) then
                options[command][1..-1].join(' ')
            else 
                ''
            end
        end
    end
end