--[[
	file: app/post/profile
	desc: update profile
]]

--modules
local user, header, request, template, countries, session = luawa.user, luawa.header, luawa.request, oxy.template, require( oxy.config.root .. 'app/countries' ).iso, luawa.session

--login? or invalid request (update type MUST be set)
if not user:checkLogin() or not request.post.update then
	return header:redirect( '/' )
end

--token?
if not request.post.token or not session:checkToken( request.post.token ) then
	return template:error( 'Invalid token' )
end

--update address?
if request.post.update == 'address' then
	--make sure we have stuff
	if not request.post.address or not request.post.country or not countries[request.post.country] then
		return template:error( 'Please fill out all details' )
	end

	--update
	local status, err = user:setData({
		address = request.post.address,
		country = request.post.country
	})
	if not status then
		return header:redirect( '/profile', 'error', err )
	else
		return header:redirect( '/profile', 'success', 'Address updated' )
	end

--update details?
else
	--make sure we have stuff
	if not request.post.name or not request.post.email then
		return template:error( 'Please provide an email and a name' )
	elseif not request.post.email:find( '^[^@]+@' ) then
		return header:redirect( '/profile', 'error', 'Please use a valid email address' )
	else
		--update
		local status, err = user:setData({
			real_name = request.post.real_name,
			name = request.post.name,
			email = request.post.email,
			password = request.post.password,
			company = request.post.company
		})
		if not status then
			return header:redirect( '/profile', 'error', err )
		else
			return header:redirect( '/profile', 'success', 'Profile updated' )
		end
	end
end