Sequel.migration do
	change do
		create_table(:server_requests) do |t|
			primary_key :id
			String :request
			String :params
			String :session

			DateTime :created_at
		end
	end	
end

