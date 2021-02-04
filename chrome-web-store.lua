dofile("table_show.lua")
dofile("urlcode.lua")
local urlparse = require("socket.url")
local http = require("socket.http")

local item_value = os.getenv('item_value')
local item_type = os.getenv('item_type')
local item_dir = os.getenv('item_dir')
local warc_file_base = os.getenv('warc_file_base')

local url_count = 0
local tries = 0
local downloaded = {}
local addedtolist = {}
local abortgrab = false

local platforms_to_try = {}
local attempted_platform_index = 0
num_good_downloads = 0
details_page_was_404 = false
extension_no_longer_available = false

all_plats_queued = false
local all_possible_platforms = {}

if urlparse == nil or http == nil then
  io.stdout:write("socket not corrently installed.\n")
  io.stdout:flush()
  abortgrab = true
end

for ignore in io.open("ignore-list", "r"):lines() do
  downloaded[ignore] = true
end

for platform in io.open("platforms.txt", "r"):lines() do
  platforms_to_try[attempted_platform_index] = platform
  attempted_platform_index = attempted_platform_index + 1
end
attempted_platform_index = 0

local a_p_p_i = 0
for platform in io.open("all_platforms.txt", "r"):lines() do
  all_possible_platforms[a_p_p_i] = platform
  a_p_p_i = a_p_p_i + 1
end
attempted_platform_index = 0

read_file = function(file)
  if file then
    local f = assert(io.open(file))
    local data = f:read("*all")
    f:close()
    return data
  else
    return ""
  end
end

allowed = function(url, parenturl)
  local tested = {}
  for s in string.gmatch(url, "([^/]+)") do
    if tested[s] == nil then
      tested[s] = 0
    end
    if tested[s] == 6 then
      return false
    end
    tested[s] = tested[s] + 1
  end
  
  if url == "https://chrome.google.com/webstore/detail/" .. item_value then
    return true
  end
  
  if string.match(url, "^https?://lh3%.googleusercontent%.com/") then
    return true
  end
  
  -- Bad URL that gets extracted from somewhere
  if string.match(url, "^https?://clients2%.google%.com/service/update2/crx")
  and not string.match(url, "response") then
    return false
  end
  
  if (string.match(url, "^https?://clients2%.googleusercontent%.com/")
  or string.match(url, "^https?://clients2%.google%.com/")) then
    return true
  end
  
  if string.match(url, "^https?://chrome%.google%.com/extensions/permalink%?id=") then
    return true
  end

  if string.match(url, "^https?://chrome%.google%.com/webstore/download/[^/]+/package/main") then
    return true
  end
  
  return false
end


wget.callbacks.download_child_p = function(urlpos, parent, depth, start_url_parsed, iri, verdict, reason)
  local url = urlpos["url"]["url"]
  local html = urlpos["link_expect_html"]

  if (downloaded[url] ~= true and addedtolist[url] ~= true)
    and allowed(url, parent["url"])
    and not string.match(url, "^https?://schema%.org") then
    addedtolist[url] = true
    return true
  end
  
  return false
end

wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}
  local html = nil
  
  downloaded[url] = true

  local function check(urla)
    local origurl = url
    local url = string.match(urla, "^([^#]+)")
    local url_ = string.match(url, "^(.-)%.?$")
    url_ = string.gsub(url_, "&amp;", "&")
    url_ = string.match(url_, "^(.-)%s*$")
    url_ = string.match(url_, "^(.-)%??$")
    url_ = string.match(url_, "^(.-)&?$")
    url_ = string.match(url_, "^(.-)/?$")
    if (downloaded[url_] ~= true and addedtolist[url_] ~= true)
      and allowed(url_, origurl) then
      table.insert(urls, { url=url_ })
      addedtolist[url_] = true
      addedtolist[url] = true
    end
  end

  local function checknewurl(newurl)
    if string.match(newurl, "^https?:////") then
      check(string.gsub(newurl, ":////", "://"))
    elseif string.match(newurl, "^https?://") then
      check(newurl)
    elseif string.match(newurl, "^https?:\\/\\?/") then
      check(string.gsub(newurl, "\\", ""))
    elseif string.match(newurl, "^\\/") then
      checknewurl(string.gsub(newurl, "\\", ""))
    elseif string.match(newurl, "^//") then
      check(urlparse.absolute(url, newurl))
    elseif string.match(newurl, "^/") then
      check(urlparse.absolute(url, newurl))
    elseif string.match(newurl, "^%.%./") then
      if string.match(url, "^https?://[^/]+/[^/]+/") then
        check(urlparse.absolute(url, newurl))
      else
        checknewurl(string.match(newurl, "^%.%.(/.+)$"))
      end
    elseif string.match(newurl, "^%./") then
      check(urlparse.absolute(url, newurl))
    end
  end

  local function checknewshorturl(newurl)
    if string.match(newurl, "^%?") then
      check(urlparse.absolute(url, newurl))
    elseif not (string.match(newurl, "^https?:\\?/\\?//?/?")
      or string.match(newurl, "^[/\\]")
      or string.match(newurl, "^%./")
      or string.match(newurl, "^[jJ]ava[sS]cript:")
      or string.match(newurl, "^[mM]ail[tT]o:")
      or string.match(newurl, "^vine:")
      or string.match(newurl, "^android%-app:")
      or string.match(newurl, "^ios%-app:")
      or string.match(newurl, "^%${")) then
      check(urlparse.absolute(url, "/" .. newurl))
    end
  end
  
  -- If good download, stop trying to download (unless Lennier1's thing activates)
  if string.match(url, "^https://clients2%.google%.com/service/update2/crx%?response=redirect") and num_good_downloads == 0
  and not (extension_no_longer_available and attempted_platform_index == #platforms_to_try - 1) then
    -- Figure out the current extension id
    extension_id = string.match(url, "=id%%3D(.-)%%")
    -- Queue the next platform
    check("https://clients2.google.com/service/update2/crx?" .. platforms_to_try[attempted_platform_index] .. "&x=id%3D" ..extension_id.. "%26installsource%3Dondemand%26uc")
    attempted_platform_index = attempted_platform_index + 1
  end
  
  -- Lennier1's thing
  -- <lennier1> Rather than literally trying every version, it would be reasonably safe to assume that if two different Chrome versions gave the same extension version, all intermediate Chrome versions would do the same.
  -- I don't like to do this myself, but...
  if num_good_downloads > 1 and (not all_plats_queued) then
    for index, value in ipairs(all_platforms) do
      checknewurl("https://clients2.google.com/service/update2/crx?" .. value .. "&x=id%3D" ..extension_id.. "%26installsource%3Dondemand%26uc")
    end
    all_plats_queued = true
  end

  
  if status_code == 200 then
    html = read_file(file)

    -- If it is a details page, queue the first CRXes, info JSON, review JSON, and permalink
    if string.match(url, "^https://chrome%.google%.com/webstore/detail/") then
      extension_id = string.match(url, "/([^/]-)$")

      -- To be safe
      if not string.match(item_value, extension_id) then
        abortgrab = true
      end

      -- Lennier1's idea - 2 diff versions
      -- Also get the commonly-DLd forms online
      check('https://clients2.google.com/service/update2/crx?response=redirect&prodversion=49.0&x=id%3D' .. extension_id .. '%26installsource%3Dondemand%26uc')
      check('https://clients2.google.com/service/update2/crx?response=redirect&prodversion=68.0&x=id%3D' .. extension_id .. '%26installsource%3Dondemand%26uc')

      -- Note sure what this is (best guess is the date of the most recent plugin update)
      date = string.match(html, '"https://accounts%.google%.com/AccountChooser","(%d%d%d%d%d%d%d%d)",%[%]')
      req_id = "11111"
    table.insert(urls, { url="https://chrome.google.com/webstore/ajax/detail?hl=en-US&gl=US&pv=" .. date .. "&mce=atf%2Cpii%2Crtr%2Crlb%2Cgtc%2Chcn%2Csvp%2Cwtd%2Chap%2Cnma%2Cdpb%2Car2%2Crp2%2Cutb%2Chbh%2Chns%2Cctm%2Cac%2Chot%2Cmac%2Cfcf%2Crma&id=" .. extension_id .. "&container=CHROME&_reqid=" .. req_id .. "&rt=j", post_data="login%3D%26"})
    table.insert(urls, {url="https://chrome.google.com/webstore/reviews/get?hl=en-US&gl=US&pv=" .. date .. "&mce=atf%2Cpii%2Crtr%2Crlb%2Cgtc%2Chcn%2Csvp%2Cwtd%2Chap%2Cnma%2Cdpb%2Car2%2Crp2%2Cutb%2Chbh%2Chns%2Cctm%2Cac%2Chot%2Cmac%2Cfcf%2Crma%2Clrc%2Cspt%2Cirt%2Cscm%2Cder%2Cbgi%2Cbem%2Crae%2Cshr%2Cdda%2Cigb%2Chib%2Cdsq%2Cqso&_reqid=" .. req_id .. "&rt=j",
                        post_data = "login=&f.req=%5B%22http%3A%2F%2Fchrome.google.com%2Fextensions%2Fpermalink%3Fid%3D" .. extension_id .. "%22%2C%22en%22%2C%5B25%5D%2C1%2C%5B2%5D%2Ctrue%5D&"})
    checknewurl("http://chrome.google.com/extensions/permalink?id=" .. extension_id)
    end
    
    -- If it is the info or review JSON, queue images (and other links from there)
    if string.match(url, "^https://chrome%.google%.com/webstore/ajax/") then
      processed_html = html
      -- Replace unicode escapes
      char_to_replace = 32
      while char_to_replace < 127 do
        --print("\u00" .. string.format("%x", char_to_replace))
        processed_html = string.gsub(processed_html, "\\u00" .. string.format("%x", char_to_replace), string.char(char_to_replace))
        char_to_replace = char_to_replace + 1
      end
      for newurl in string.gmatch(processed_html, '"(https?://[^"]-)"') do
        checknewurl(newurl)
      end
    end
  end
    

  -- Something in here was getting bad results
--   if allowed(url, nil) and status_code == 200 then
--     html = read_file(file)
--     for newurl in string.gmatch(string.gsub(html, "&quot;", '"'), '([^"]+)') do
--       checknewurl(newurl)
--     end
--     for newurl in string.gmatch(string.gsub(html, "&#039;", "'"), "([^']+)") do
--       checknewurl(newurl)
--     end
--     for newurl in string.gmatch(html, ">%s*([^<%s]+)") do
--       checknewurl(newurl)
--     end
--     for newurl in string.gmatch(html, "[^%-]href='([^']+)'") do
--       checknewshorturl(newurl)
--     end
--     for newurl in string.gmatch(html, '[^%-]href="([^"]+)"') do
--       checknewshorturl(newurl)
--     end
--     for newurl in string.gmatch(html, ":%s*url%(([^%)]+)%)") do
--       checknewurl(newurl)
--     end
--   end

  return urls
end

wget.callbacks.httploop_result = function(url, err, http_stat)
  status_code = http_stat["statcode"]
  
  url_count = url_count + 1
  io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. "  \n")
  io.stdout:flush()
  
  -- If it's CRX{2,3}-only URL, no issue
  if string.match(url["url"], '^https://clients2%.google%.com/service/update2/crx%?response=redirect') and status_code == 204 then
    return wget.actions.EXIT
  end
  
  -- If it's a good download, increment the counter
  if string.match(url["url"], "^https://clients2%.googleusercontent%.com/crx/blobs/") and status_code == 200 then
    num_good_downloads = num_good_downloads + 1
  end

  -- Why this endpoint even exists, when it always seems to give 401s even on valid extensions, I don't know
  -- (normally, it will only be grabbed when one of the response=redirect URLs redirect to it, which only seems
  --  to happen on these extensions)
  if string.match(url["url"], "^https?://chrome%.google%.com/webstore/download/[^/]+/package/main") and status_code == 401 then
    extension_no_longer_available = true
    return wget.actions.EXIT
  end


  if status_code >= 300 and status_code <= 399 then
    local newloc = urlparse.absolute(url["url"], http_stat["newloc"])
    if downloaded[newloc] == true or addedtolist[newloc] == true
      or not allowed(newloc, url["url"]) then
      tries = 0
      return wget.actions.EXIT
    end
  end
  
  if status_code >= 200 and status_code <= 399 then
    downloaded[url["url"]] = true
  end

  if abortgrab == true then
    io.stdout:write("ABORTING...\n")
    io.stdout:flush()
    return wget.actions.ABORT
  end

  if status_code ~= 200 and status_code ~= 404 and status_code ~= 302 then
    io.stdout:write("Server returned " .. http_stat.statcode .. " (" .. err .. "). Sleeping.\n")
    io.stdout:flush()
    local maxtries = 12
    if not allowed(url["url"], nil) then
      maxtries = 3
    end
    if tries >= maxtries then
      io.stdout:write("I give up...\n")
      io.stdout:flush()
      tries = 0
      if maxtries == 3 then
        return wget.actions.EXIT
      else
        return wget.actions.ABORT
      end
    else
      os.execute("sleep " .. math.floor(math.pow(2, tries)))
      tries = tries + 1
      return wget.actions.CONTINUE
    end
  end

  tries = 0

  local sleep_time = 0

  if sleep_time > 0.001 then
    os.execute("sleep " .. sleep_time)
  end

  if url_count == 1 and status_code == 404 then
    details_page_was_404 = true
  end

  return wget.actions.NOTHING
end

wget.callbacks.before_exit = function(exit_status, exit_status_string)
  if abortgrab == true then
    return wget.exits.IO_FAIL
  end
  if num_good_downloads == 0 and not details_page_was_404 and not extension_no_longer_available then
    print("Downloaded no crx files")
    return wget.exits.IO_FAIL
  end
  return exit_status
end

