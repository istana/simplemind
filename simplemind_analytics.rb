require 'sqlite3'
require 'sequel'
require 'oj'

Sequel.extension :migration

module Simplemind
	module Analytics

		class << self
			def db
				Sequel.connect('sqlite://db/analytics.sqlite3')
			end

			def log_request(request, session, params)
				db[:server_requests].insert(
					created_at: Time.now,
					request: Oj.dump(secure_request(request.env)),
					session: Oj.dump(session),
					params: Oj.dump(params)
				)
			end

			def log_piwik(request, session, params)
				db[:piwik_requests].insert(
					created_at: Time.now,
					request: Oj.dump(secure_request(request.env)),
					session: Oj.dump(session),
					params: Oj.dump(params)
				)
			end

			def migrate!
				Sequel::Migrator.run(db, "db/migrations/analytics")
			end

			private

			# secure_ make k (string) => v (string)
			# records, so no nesting
			# and limit size of hash

			# max 50 params
			# max 4k
			def secure_params(hash)
				hash	
			end

			# max 4k
			def secure_request(hash)
				# skip stringio and io classes and never modify original request
				# otherwise sinatra will fail
				# also skip rack stuff
				#
				h = {}

				hash.each do |k,v|
					if k =~ /\A[A-Z_]+\z/ && !v.respond_to?(:to_io)
						h[k] = v.to_s
					end
				end
				h
			end

			def secure_session

			end
		end

	end
end

