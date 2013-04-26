#!/usr/bin/env lua

--[[
    file: build.lua
    desc: Oxypanel build
        + creates oxyngx.lua for Nginx
        + creates oxynode.js for Node
]]

--localize
local type, pairs, tostring, io, oxy, table = type, pairs, tostring, io, oxy, table

--get app/luawa config
local luawaconf = require( 'config' )

--[[
    bits
]]
local nginx_config = function( config ) return [[#shared bits
lua_shared_dict ]] .. luawaconf.shm_prefix .. [[cache_app 1m;
lua_shared_dict ]] .. luawaconf.shm_prefix .. [[cache_template 1m;
lua_shared_dict ]] .. luawaconf.shm_prefix .. [[session 10m;
lua_shared_dict ]] .. luawaconf.shm_prefix .. [[user 10m;

server {
    #port & domains
    listen ]] .. luawaconf.oxyngx.port .. [[;
    server_name oxypanel.dev api.oxypanel.dev;

    #dev mode
    lua_code_cache off;

    #logging
    error_log ]] .. config.root .. [[logs/error.log;
    access_log ]] .. config.root .. [[logs/access.log;

    #error pages
    error_page 404 /inc/error/404.html;
    error_page 500 /inc/error/500.html;

    #rewrite url                        #request                                        #method

    #inc is ok
    rewrite ^/inc/(.*)$                 /inc/$1 last;

    #core
    rewrite ^/$                         /?request=dashboard last;                       #get
    rewrite ^/login$                    /?request=login last;                           #get+post
    rewrite ^/logout$                   /?request=logout last;                          #get
    rewrite ^/register$                 /?request=register last;                        #get+post
    rewrite ^/resetpw$                  /?request=resetpw last;                         #get+post
    rewrite ^/profile$                  /?request=profile last;                         #get+post
    rewrite ^/help$                     /?request=help last;                            #get

    #catch objects
    rewrite ^/([aA-zZ]+)/([0-9]+)$    /?request=object&type=$1&id=$2 last;      #get
    rewrite ^/([aA-zZ]+)/([0-9]+)/([aA-zZ]+)$    /?request=object&type=$1&id=$2&action=$3 last;      #get+post

    #catch modules
    rewrite ^/([aA-zZ]+)$               /?request=module&module=$1 last;         #get+post
    rewrite ^/([aA-zZ]+)/([aA-zZ]+)$               /?request=module&module=$1&mreq=$2 last;         #get+post
    rewrite ^/([aA-zZ]+)/([aA-zZ]+)/([aA-zZ]+)$               /?request=module&module=$1&mreq=$2&action=$3 last;         #get+post

    #else 404
    return 404;

    #default server dir
    location / {
        default_type 'text/html';
        content_by_lua_file ]] .. config.root .. [[oxyngx.lua;
    }

    #static content
    location /inc {
        root ]] .. config.root .. [[;
    }
}]] end



--do node config
local node_config = function( files )
    --start output
    local out = '//autogenerated by oxypanel\n'
    --server port a port or socket?
    local server_port = luawaconf.oxynode.server_port
    if type( server_port ) == 'string' then
        server_port = "'" .. server_port .. "'"
    end
    --add code
    out = out .. [[module._autoconf = {
    client_port: ]] .. luawaconf.oxynode.client_port .. [[,
    server_port: ]] .. server_port .. [[,
    share_key: ']] .. luawaconf.oxynode.share_key .. [[',
    user_strength: ]] .. luawaconf.user.strength .. [[

};]] .. '\n\n'

    for k, file in pairs( files ) do
        out = out .. 'require( \'./' .. file .. '\' );\n'
    end
    return out
end



--do clientside javascript
local client_js = function() return [[
var oxypanel = {
    user_strength: ]] .. luawaconf.user.strength .. [[

};]] end



--[[
    util functions
]]
--overwrite print
local oldprint = print
local print = function( text )
    oldprint( '[Oxypanel]: ' .. tostring( text ) )
end

--turn a lua table into lua code
local function tableToLua( table, indent )
    indent = indent or 0
    local out = ''

    for k, v in pairs( table ) do
        out = out .. '\n'
        for i = 0, indent do
            out = out .. '\t'
        end
        if type( v ) == 'table' then
            out = out .. k .. ' = {' .. tableToLua( v, indent + 1 ) .. '\n'
            for i = 0, indent do
                out = out .. '\t'
            end
            out = out .. '},'
        else
            if type( v ) == 'function' then v = tostring( v() ) end
            if type( v ) == 'string' then v = "'" .. v .. "'" end
            if type( v ) == 'boolean' then v = tostring( v ) end
            if type( k ) == 'number' then k = '' else k = k .. ' = ' end
            out = out .. k .. v .. ','
        end
    end
    out = out:sub( 0, out:len() - 1 )

    return out
end

--table count
local function tableCount( table )
    local i = 0
    for k,v in pairs( table ) do
        i = i + 1
    end
    return i
end

--list a directory
function ls( directory )
    local out = {}
    local f, err = io.popen( 'ls ' .. directory )
    if not f then error( err ) end
    local module = f:read( '*l' )
    while module ~= nil do
        table.insert( out, module )
        module = f:read( '*l' )
    end
    return out
end




--[[
    request functions
]]
--build oxypanel.lua * config.nginx
local function build()
    print( 'BUILD START' )

    --conf to build
    local _autoconf = {
        modules = {},
        objects = {},
        oxyngx = luawaconf.oxyngx,
        oxynode = luawaconf.oxynode
    }
    --node files to include
    local node_files = {}

    --root directory
    print( 'Getting current directory' )
    local f, err = io.popen( 'pwd' )
    if not f then error( err ) end
    local root, err = f:read( '*l' )
    if not root then error( err ) end
    root = root .. '/'
    _autoconf.root = root
    print( '\tRoot directory set to: ' .. root )

    --scan for modules
    print( 'Scanning for modules...' )
    for k, module in pairs( ls( 'modules/' ) ) do
        _autoconf.modules[module] = module
        _autoconf[module] = {}
        print( '\tFound module: ' .. module )
        module = f:read( '*l' )
    end

    --for each module, load their objects from their config
    for k, module in pairs( _autoconf.modules ) do
        print( 'Building ' .. module .. ' config...' )
        local config = require( 'modules/' .. module .. '/config' )

        --name
        _autoconf[module].name = config.name
        --do requests
        _autoconf[module].requests = config.requests
        print( '\t' .. ( tableCount( config.requests.get ) + tableCount( config.requests.post ) ) .. ' requests added' )

        --do objects
        for object, d in pairs( config.objects ) do
            print( '\tObject added: ' .. object )
            d.module = module
            _autoconf.objects[object] = d
            if not d.hidden then
                _autoconf[module].requests.get[object .. 's'] = { file = '../../app/get/objects', args = { type = object } }
            end
        end

        --do autoconfs
        if config.autoconf then
            for key, conf in pairs( config.autoconf ) do
                _autoconf[module][key] = conf()
                print( '\tData configured: ' .. key )
            end
        end

        --node files?
        if config.node then
            for _, file in pairs( config.node ) do
                table.insert( node_files, 'modules/' .. module .. '/node/' .. file )
            end
        end
    end

    --start output
    local output = '--autogenerated by Oxypanel\n_autoconf = {' .. tableToLua( _autoconf )
    --add ngx stuff
    output = output .. [[

}
--get luawa & set config
luawa = require( _autoconf.root .. 'luawa/core' )
luawa:setConfig( _autoconf.root, 'config' )


--set oxypanel & set config
oxy = require( _autoconf.root .. 'app/core' )
oxy:setConfig( _autoconf )

--run luawa
luawa:run()]]

    --open oxypanel.lua + write
    print( 'Writing oxypanel.lua...' )
    local f, err = io.open( 'oxyngx.lua', 'w' )
    if not f then error( err ) end
    local status, err = f:write( output )
    if not status then error( err ) end
    print( '\toxypanel.lua written' )

    --oxynode.js
    print( 'Writing oxynode.js...' )
    local f, err = io.open( 'oxynode.js', 'w' )
    if not f then error( err ) end
    local status, err = f:write( node_config( node_files ) )
    if not status then error( err ) end
    print( '\toxynode.js written' )

    --oxypanel.js clientside
    print( 'Writing oxypanel.js...' )
    local f, err = io.open( 'inc/js/oxypanel.js', 'w' )
    if not f then error( err ) end
    local status, err = f:write( client_js() )
    if not status then error( err ) end
    print( '\toxypanel.js written' )

    --config.nginx
    print( 'Writing config.nginx...' )
    local f, err = io.open( 'config.nginx', 'w' )
    if not f then error( err ) end
    local status, err = f:write( nginx_config( { root = _autoconf.root } ) )
    if not status then error( err ) end
    print( '\tconfig.nginx written' )

    print( 'BUILD COMPLETE' )
end


--nginx/oxypanel status
local function status()
    print( 'status' )
    --get nginx pid /status
    local status = io.popen( 'pidfile status' )
    print( status:read( '*a' ) )
end






return build()

--[[
    deal with our request

--status?
if arg[1] == 'status' then
    return status()
--build?
elseif arg[1] == 'build' then
    return build()
--no argument set?
else
    return print( 'Please use lua oxycli.lua <status|build>' )
end
]]