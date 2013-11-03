--locals
local template, network, user = oxy.template, oxy.network, luawa.user

--owned services
template:set( 'devices', network.device:getOwned( {}, 'id DESC', 20  ), true )

--owned ip blocks
template:set( 'ipblocks', network.ipblock:getOwned( {}, 'id DESC', 20 ), true )

--owned groups
template:set( 'groups', network.group:getOwned( {}, 'id DESC', 20 ), true )

--page title
template:set( 'page_title', 'Network Devices' )
if user:checkPermission( 'ViewAnyDevice' ) then
	template:set( 'page_title_buttons', { { class = 'admin', link = '/network/devices/all', text = 'View All' } } )
end

--template
template:load( 'core/header' )
template:loadModule( 'network', 'dashboard' )
template:load( 'core/footer' )