from PMS import Plugin, Log, XML, HTTP, JSON, Prefs, RSS
from PMS.MediaXML import *
from PMS.FileTypes import PLS
from PMS.Shorthand import _L, _R, _E, _D
import re

# TODO support Bonjour
PLUGIN_PREFIX = "/video/remedie"
FEED_URL = "http://localhost:10010/"

####################################################################################################

def Start():
  Plugin.AddRequestHandler(PLUGIN_PREFIX, HandleRequest, "Remedie", "icon-default.png", "art-default.jpg")
  Plugin.AddViewGroup("InfoList", viewMode="InfoList", contentType="items")
  Plugin.AddViewGroup("List", viewMode="List", contentType="items")

####################################################################################################

def HandleRequest(pathNouns, count):
  try:
    title2 = pathNouns[count-1].split("||")[1]
    pathNouns[count-1] = pathNouns[count-1].split("||")[0]
  except:
    title2 = ""

  dir = MediaContainer("art-default.jpg", viewGroup="List", title1="Remedie", title2=title2.decode("utf-8"))
  if count == 0:
    dict = JSON.DictFromURL(FEED_URL + "rpc/channel/load");
    for e in dict[u'channels']:
      id    = e[u'id']
      title = e[u'name']
      if e[u'unwatched_count']:
        title += ' (' + str(e[u'unwatched_count']) + ')'
      thumb = "icon-default.png"
      if u'thumbnail' in e[u'props']:
        thumb = e[u'props'][u'thumbnail'][u'url']
      Log.Add(thumb)
      dir.AppendItem(DirectoryItem("feed^" + str(id) + "||" + title, title, _R(thumb)))
    
  elif pathNouns[0].startswith("feed"):
    channel_id = pathNouns[0].split("^")[1]
    dict = JSON.DictFromURL(FEED_URL + "rpc/channel/show?id=" + channel_id)
    dir.SetViewGroup("InfoList")
    for e in dict[u'items']:
      type = e[u'props'][u'type']
      id = PLUGIN_PREFIX + "/play^" + _E(e[u'ident']) + "^" + type
      title = e[u'name']
      summary = e[u'props'][u'description']
      duration = ""
      thumb = ""
      if u'thumbnail' in e[u'props']:
        thumb = e[u'props'][u'thumbnail'][u'url']
      elif u'thumbnail' in dict[u'channel'][u'props']:
        thumb = dict[u'channel'][u'props'][u'thumbnail'][u'url']
      # TODO maybe special case YouTube
      # TODO rtmp or mms seems not to work with Redirects
      if re.match('^video/', type):
        vidItem = VideoItem(id, e[u'name'], summary, duration, thumb)
      else:
        Log.Add(e[u'props'][u'link'])
        vidItem = WebVideoItem(e[u'props'][u'link'], e[u'name'], summary, duration, thumb)
      dir.AppendItem(vidItem)

  elif pathNouns[0].startswith("play"):
    # TODO mark it read
    paths = pathNouns[0].split("^")
    Log.Add(paths)
    url  = _D(paths[1])
    type = paths[2]
    Log.Add(url)
    return Plugin.Redirect(url)
    
  return dir.ToXML()
####################################################################################################
