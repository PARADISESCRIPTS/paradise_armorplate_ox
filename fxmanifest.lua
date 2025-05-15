fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Paradise'
version '1.0.0'
description 'Armor Plate System'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

server_scripts {
    'scripting/server.lua'
}

client_scripts {
    'scripting/client.lua'
}