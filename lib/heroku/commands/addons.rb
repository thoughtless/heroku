module Heroku::Command
	class Addons < BaseWithApp
		def list
			addons = heroku.addons
			if addons.empty?
				display "No addons available currently"
			else
				installed = heroku.installed_addons(app)
				available = addons.select { |a| !installed.include? a }

				display 'Activated addons:'
				if installed.empty?
					display '  (none)'
				else
					installed.each { |a| addon_display(a) }
				end

				display ''
				display 'Available addons:'
				available.each { |a| addon_display(a) }
			end
		end
		alias :index :list

		def add
			addon = args.shift
			config = {}
			args.each do |arg|
				key, value = arg.strip.split('=', 2)
				if value.nil?
					addon_error("Non-config value \"#{arg}\".  Everything after the addon name should be a key=value pair.")
					exit 1
				else
					config[key] = value
				end
			end

			display "Adding #{addon} to #{app}...", false
			display addon_run { heroku.install_addon(app, addon, config) }
		end

		def remove
			args.each do |name|
				display "Removing #{name} from #{app}...", false
				display addon_run { heroku.uninstall_addon(app, name) }
			end
		end

		def clear
			heroku.installed_addons(app).each do |addon|
				display "Removing #{addon['description']} from #{app}...", false
				display addon_run { heroku.uninstall_addon(app, addon['name']) }
			end
		end

		def confirm_billing
			display("This action will cause your account to be billed at the end of the month")
			display("Are you sure you want to do this? (y/n) ", false)
			if ask.downcase == 'y'
				heroku.confirm_billing
				return true
			end
		end

		private
			def addon_display(attr)
				space = ' ' * [1, (24 - attr['description'].size)].max
				display "  #{attr['description']}#{space}#{attr['url']}"
			end

			def addon_run
				yield
				'Done.'
			rescue RestClient::ResourceNotFound => e
				addon_error("no addon by that name")
			rescue RestClient::RequestFailed => e
				if e.http_code == 402
					confirm_billing ? retry : 'Canceled'
				else
					error = Heroku::Command.extract_error(e.http_body)
					addon_error(error)
				end
			end

			def addon_error(message)
				"FAILED\n" + message.split("\n").map { |line| '!    ' + line }.join("\n")
			end
	end
end
