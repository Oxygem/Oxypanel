-- Oxypanel Core
-- File: app/get/objects.lua
-- Desc: List objects

-- Locals
local request, head, user, session = luawa.request, luawa.header, luawa.user, luawa.session
local oxy, template = oxy, oxy.template

--no object set, no object match or hidden object
if not request.args.type or not oxy.config.objects[request.args.type] then
    return header:redirect('/')
end

--module & type
local module, object_type, action_template = oxy[request.get.module], request.args.type, 'list'
local object_conf = oxy.config.objects[object_type]


--add page?
if request.get.action == 'add' then
    template:set('page_title', 'Add ' .. object_conf.name)

    if not user:checkPermission('Add' .. object_type) then
        session:addMessage('error', 'You do not have permission to add ' .. object_type .. 's')
    else
        action_template = 'add'
    end


--else listing (default)
else
    --set page title
    template:set('page_title', object_conf.names)

    --match filters
    local wheres = {}
    if object_conf.filters then
        for k, filter in pairs(object_conf.filters) do
            if request.get[filter] and (type(request.get[filter]) == 'table' or (type(request.get[filter]) == 'string' and request.get[filter] ~= '')) then
                wheres[filter] = request.get[filter]
            end
        end
    end

    --pagination
    local page = 1
    if request.get.page and type(tonumber(request.get.page)) == 'number' then
        page = request.get.page
    end

    --get services
    local objects, err
    if request.get.action == 'all' then
        objects, err = module[object_type]:getAll(wheres, { order = 'id DESC', limit = 30, offset = (page - 1) * 30 })
        template:set('page_title_meta', 'owned by anyone')
    else
        objects, err = module[object_type]:getOwned(wheres, { order = 'id DESC', limit = 30, offset = (page - 1) * 30 })
        template:set('page_title_meta', 'owned by you')
    end
    --error (permissions error normally/hopefully)
    if err then
        return template:error(err)
    else
        template:set(object_type .. 's', objects, true)
    end
end


--load templates
template:wrap(request.get.module, object_type .. '/' .. action_template)