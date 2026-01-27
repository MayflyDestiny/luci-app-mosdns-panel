module("luci.controller.mosdns_panel", package.seeall)

function index()
    -- API endpoint for the panel to fetch status
    entry({"mosdns_panel", "api", "status"}, call("action_status")).public = true
    entry({"mosdns_panel", "api", "background_status"}, call("action_bg_status")).public = true
    entry({"mosdns_panel", "api", "upload_background"}, call("action_upload_background")).public = true
    entry({"mosdns_panel", "api", "remove_background"}, call("action_remove_background")).public = true
    entry({"mosdns_panel", "api", "restart"}, call("action_restart")).public = true
    entry({"mosdns_panel", "api", "get_log"}, call("action_get_log")).public = true
    entry({"mosdns_panel", "api", "clear_log"}, call("action_clear_log")).public = true
    entry({"mosdns_panel", "api", "restore_dump"}, call("action_restore_dump")).leaf = true
    entry({"mosdns_panel", "plugins"}, call("action_plugins")).leaf = true
end

local function parse_metrics(metrics_text)
    local data = {
        caches = {},
        system = {
            go_version = "N/A"
        }
    }
    
    if not metrics_text then return data end

    local latency_sum = 0
    local latency_count = 0

    for line in metrics_text:gmatch("[^\r\n]+") do
        -- mosdns_cache_query_total{tag="lazy_cache"} 0
        local metric, tag, value = line:match("^(mosdns_cache_[%w_]+){tag=\"([^\"]+)\"}%s+([%d%.eE+-]+)")
        if metric then
            if not data.caches[tag] then data.caches[tag] = {} end
            -- Remove prefix "mosdns_cache_"
            local key = metric:match("^mosdns_cache_(.+)")
            if key then
                data.caches[tag][key] = tonumber(value)
            end
        else
            -- Check for latency metrics
            local l_sum = line:match("^mosdns_metrics_collector_response_latency_millisecond_sum{name=\"metrics\"}%s+([%d%.eE+-]+)")
            if l_sum then latency_sum = tonumber(l_sum) end
            
            local l_count = line:match("^mosdns_metrics_collector_response_latency_millisecond_count{name=\"metrics\"}%s+([%d%.eE+-]+)")
            if l_count then latency_count = tonumber(l_count) end

            -- System metrics
            local sys_key, sys_val = line:match("^([%w_]+)%s+([%d%.eE+-]+)")
            if sys_key then
                if sys_key == "process_start_time_seconds" then data.system.start_time = tonumber(sys_val)
                elseif sys_key == "process_cpu_seconds_total" then data.system.cpu_time = tonumber(sys_val)
                elseif sys_key == "process_resident_memory_bytes" then data.system.resident_memory = tonumber(sys_val)
                elseif sys_key == "go_memstats_heap_idle_bytes" then data.system.heap_idle_memory = tonumber(sys_val)
                elseif sys_key == "go_threads" then data.system.threads = tonumber(sys_val)
                elseif sys_key == "process_open_fds" then data.system.open_fds = tonumber(sys_val)
                end
            else
                 -- go_info{version="go1.22.3"} 1
                 local ver = line:match('^go_info{version="([^"]+)"}')
                 if ver then data.system.go_version = ver end
            end
        end
    end

    -- Calculate derived stats
    if latency_count > 0 then
        data.system.avg_latency = latency_sum / latency_count
    else
        data.system.avg_latency = 0
    end

    for tag, metrics in pairs(data.caches) do
        local query_total = metrics.query_total or 0
        local hit_total = metrics.hit_total or 0
        local lazy_hit_total = metrics.lazy_hit_total or 0
        
        metrics.hit_rate = (query_total > 0) and string.format("%.2f%%", (hit_total / query_total * 100)) or "0.00%"
        metrics.lazy_hit_rate = (query_total > 0) and string.format("%.2f%%", (lazy_hit_total / query_total * 100)) or "0.00%"
    end

    return data
end

function action_status()
    local sys = require "luci.sys"
    local http = require "luci.http"
    local jsonc = require "luci.jsonc"
    
    -- Try 9091 (from shell script) and 9099 (from app.py default)
    local metrics = sys.exec("curl -s --max-time 2 http://127.0.0.1:9091/metrics")
    
    local data = parse_metrics(metrics)
    
    http.prepare_content("application/json")
    http.write(jsonc.stringify(data))
end

function action_bg_status()
    local http = require "luci.http"
    local jsonc = require "luci.jsonc"
    http.prepare_content("application/json")
    http.write(jsonc.stringify({status="default"}))
end

function action_upload_background()
    local http = require "luci.http"
    local jsonc = require "luci.jsonc"
    http.prepare_content("application/json")
    http.write(jsonc.stringify({success=false, error="Feature not supported in LuCI panel version"}))
end

function action_remove_background()
    local http = require "luci.http"
    local jsonc = require "luci.jsonc"
    http.prepare_content("application/json")
    http.write(jsonc.stringify({success=false, error="Feature not supported in LuCI panel version"}))
end

function action_restart()
    local sys = require "luci.sys"
    local http = require "luci.http"
    local jsonc = require "luci.jsonc"
    
    local result = sys.call("/etc/init.d/mosdns restart")
    
    http.prepare_content("application/json")
    if result == 0 then
        http.write(jsonc.stringify({success=true}))
    else
        http.write(jsonc.stringify({success=false, error="Restart failed with exit code " .. tostring(result)}))
    end
end

function action_restore_dump(plugin_name)
    local sys = require "luci.sys"
    local http = require "luci.http"
    local jsonc = require "luci.jsonc"
    
    http.prepare_content("application/json")

    if not plugin_name then
        http.write(jsonc.stringify({success=false, error="Plugin name is required"}))
        return
    end

    -- Sanitize plugin name
    plugin_name = plugin_name:gsub("[^%w_%-]", "")

    -- 1. Determine Port
    local port = "9091"
    if sys.call("curl -s --max-time 1 http://127.0.0.1:9091/metrics >/dev/null 2>&1") ~= 0 then
        port = "9099"
    end

    -- 2. Determine Dump File Path
    -- Strategy: Scan YAML config first to verify plugin usage and get dump_file path
    local dump_file = nil
    local config_found = false
    
    local yamls = sys.exec("ls /etc/mosdns/*.yaml 2>/dev/null")
    if yamls and yamls ~= "" then
        for filename in yamls:gmatch("[^\r\n]+") do
            local file = io.open(filename, "r")
            if file then
                local content = file:read("*a")
                file:close()
                
                if content then
                    local in_target_block = false
                    for line in content:gmatch("[^\r\n]+") do
                        -- Check for ANY tag start: "- tag: name"
                        local tag_val = line:match("^%s*-%s*tag:%s*['\"]?([%w_%-]+)['\"]?")
                        
                        if tag_val then
                            -- New tag found
                            if tag_val == plugin_name then
                                in_target_block = true
                                config_found = true
                            else
                                in_target_block = false
                            end
                        elseif in_target_block then
                            -- Inside the target block, look for dump_file
                            local d = line:match("^%s*dump_file:%s*(.+)")
                            if d then
                                -- Remove comments if any
                                d = d:gsub("%s*#.*$", "")
                                -- Trim whitespace and quotes
                                dump_file = d:gsub("^%s*(.-)%s*$", "%1"):gsub("['\"]", "")
                                break -- Found the dump file, stop scanning this file
                            end
                        end
                    end
                end
            end
            -- If we found the config and the dump_file, we can stop searching all files
            if config_found and dump_file then break end
        end
    end

    -- 3. Validation and Fallback
    if not config_found then
        http.write(jsonc.stringify({success=false, error="未在配置文件中找到插件: " .. plugin_name}))
        return
    end

    -- If config found but no dump_file specified, use default
    if not dump_file then
        dump_file = "/etc/mosdns/" .. plugin_name .. ".dump"
    end

    -- 4. Check file existence
    if sys.call("test -f " .. dump_file) ~= 0 then
        http.write(jsonc.stringify({success=false, error="未找到本地缓存文件: " .. dump_file}))
        return
    end

    -- 5. Execute Curl

    local cmd = string.format("curl -s -X POST http://127.0.0.1:%s/plugins/%s/load_dump -H 'Content-Type: application/octet-stream' --data-binary '@%s'", port, plugin_name, dump_file)
    local exit_code = sys.call(cmd)

    if exit_code == 0 then
        http.write(jsonc.stringify({success=true, message="已恢复缓存规则", file=dump_file}))
    else
        http.write(jsonc.stringify({success=false, error="Curl execution failed", code=exit_code}))
    end
end

function action_plugins(...)
    local sys = require "luci.sys"
    local http = require "luci.http"
    local table = require "table"
    
    local args = {...}
    local path = table.concat(args, "/")
    
    -- Determine port by checking metrics endpoint
    local port = "9091"
    local check = sys.exec("curl -s --max-time 1 http://127.0.0.1:9091/metrics | head -n 1")
    if not check or check == "" then
        port = "9099"
    end
    
    -- Check if it is a dump request
    if args[#args] == "dump" then
        -- Execute command to unzip and filter domains
        -- Using grep -aoE '([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}\.?'
        local cmd
        if path == "cache_all/dump" then
            -- Special handling for cache_all: combine cache_cn, cache_nocn and lazy_cache
            cmd = string.format("(curl -s --max-time 10 'http://127.0.0.1:%s/plugins/cache_cn/dump' | gunzip -c | grep -aoE '([a-zA-Z0-9-]+\\.)+[a-zA-Z]{2,}\\.?'; curl -s --max-time 10 'http://127.0.0.1:%s/plugins/cache_nocn/dump' | gunzip -c | grep -aoE '([a-zA-Z0-9-]+\\.)+[a-zA-Z]{2,}\\.?'; curl -s --max-time 10 'http://127.0.0.1:%s/plugins/lazy_cache/dump' | gunzip -c | grep -aoE '([a-zA-Z0-9-]+\\.)+[a-zA-Z]{2,}\\.?')", port, port, port)
        else
            cmd = string.format("curl -s --max-time 10 'http://127.0.0.1:%s/plugins/%s' | gunzip -c | grep -aoE '([a-zA-Z0-9-]+\\.)+[a-zA-Z]{2,}\\.?'", port, path)
        end
        
        local content = sys.exec(cmd)
        
        -- Wrap in HTML for better viewing
        http.prepare_content("text/html; charset=utf-8")
        http.write("<!DOCTYPE html><html><head><meta charset='utf-8'><title>Dump View - " .. path .. "</title>")
        http.write("<style>body{font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif;padding:2rem;line-height:1.6;background-color:#f7f9fd;color:#2c3e50;max-width:1200px;margin:0 auto;}")
        http.write(".container{background:#ffffff;padding:2rem;border-radius:0.8rem;box-shadow:0 6px 18px rgba(0,0,0,0.08);border:1px solid #e0e6ec;}")
        http.write("h1{font-size:1.5rem;margin-top:0;margin-bottom:1rem;color:#2c3e50;border-bottom:2px solid #f0f4f7;padding-bottom:0.5rem;}")
        http.write(".count-badge{display:inline-block;background-color:#4a90e2;color:#fff;padding:0.2rem 0.6rem;border-radius:1rem;font-size:0.9rem;font-weight:bold;margin-left:0.5rem;vertical-align:middle;}")
        http.write("pre{background-color:#f8f9fa;padding:1rem;border-radius:0.5rem;border:1px solid #e9ecef;overflow-x:auto;font-family:Consolas,Monaco,'Courier New',monospace;font-size:0.9rem;color:#495057;white-space:pre-wrap;word-break:break-all;}")
        http.write("</style></head><body>")
        
        -- Count lines
        local _, count = content:gsub('\n', '\n')
        if content ~= "" and content:sub(-1) ~= "\n" then count = count + 1 end
        if content == "" then count = 0 end

        http.write("<div class='container'>")
        http.write("<h1>" .. path .. "<span class='count-badge'>" .. count .. " items</span></h1>")
        
        if content == "" then
             http.write("<div style='color:#7f8c8d;font-style:italic;'>No content found or empty dump.</div>")
        else
             http.write("<pre>" .. content .. "</pre>")
        end
        
        http.write("</div></body></html>")
    else
        local content = sys.exec("curl -s --max-time 10 http://127.0.0.1:" .. port .. "/plugins/" .. path)
        
        http.prepare_content("text/plain; charset=utf-8")
        http.write(content)
    end
end

function action_get_log()
    local sys = require "luci.sys"
    local http = require "luci.http"
    local jsonc = require "luci.jsonc"

    http.prepare_content("application/json")

    -- Default log path
    local log_file = "/var/log/mosdns.log"
    
    -- Check if default file exists
    if sys.call("test -f " .. log_file) ~= 0 then
        -- Try to find in config files as fallback
        local config_dir = "/etc/mosdns/"
        local yamls = sys.exec("ls " .. config_dir .. "*.yaml 2>/dev/null")
        local found = false
        if yamls then
            for filename in yamls:gmatch("[^\r\n]+") do
                local file = io.open(filename, "r")
                if file then
                    local content = file:read("*a")
                    file:close()
                    -- Look for "file: /path/to/log" inside "log:" block?
                    -- Simple heuristic: look for "file:.*log"
                    local f = content:match("file:%s*[\"']?([^\"'\r\n]+%.log)[\"']?")
                    if f then
                        log_file = f
                        found = true
                        break
                    end
                end
            end
        end
        
        if not found and sys.call("test -f " .. log_file) ~= 0 then
            http.write(jsonc.stringify({success=false, error="Log file not found at " .. log_file}))
            return
        end
    end

    -- Read last N lines (default 1000, max 10000)
    local limit = tonumber(http.formvalue("limit")) or 1000
    if limit > 10000 then limit = 10000 end
    if limit < 100 then limit = 100 end

    local content = sys.exec("tail -n " .. limit .. " " .. log_file)
    
    http.write(jsonc.stringify({success=true, content=content, file=log_file}))
end

function action_clear_log()
    local sys = require "luci.sys"
    local http = require "luci.http"
    local jsonc = require "luci.jsonc"

    local log_file = "/var/log/mosdns.log"
    -- Try to clear the log file
    local code = sys.call(": > " .. log_file)
    
    http.prepare_content("application/json")
    if code == 0 then
        http.write(jsonc.stringify({success=true}))
    else
        http.write(jsonc.stringify({success=false, error="Failed to clear log file"}))
    end
end
