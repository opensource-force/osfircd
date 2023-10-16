import asyncdispatch, asyncnet, strutils, strformat, net, times
import ./data
import ./responses

proc sendClient*(c: Client, text: string) {.async.} =
  await c.socket.send(text & "\c\L")

# getClientbyNickname
# Finds a connected client by nickname
proc getClientbyNickname*(nick: string): Client =
  for a in s.clients:
    if a.nickname == nick:
      return a

proc getEpochTime*(): int =
  let time = split($epochTime(), ".")
  
  return parseInt(time[0])

proc pingClient*(c: Client) =
  discard c.sendClient("PING")

  c.timestamp = getEpochTime()

proc checkLiveliness*(c: Client) {.async.} =
  while true:
    # if now is 60 more than timestamp
    if getEpochTime() - c.timestamp > 60:
      c.pingClient()
    
    # check every 10 sec
    await sleepAsync(10000)

# sendLuser
# Sends the LUSER command output to a connected client
proc sendLuser*(c: Client) {.async.} =
  let userCount = 0
  let invisibleCount = 0
  let onlineOperCount = 0
  let unknownConnectionCount = 0
  let channelCount = 0
  let serverCount = 0
  let sName = getPrimaryIPAddr()
  let uName = c.nickname

  var part: array[5, string]
  part[0] = fmt":{sName} 251 {uName} :There are {userCount} users and {invisibleCount} invisible on {serverCount} servers"
  part[1] = fmt":{sName} 252 {uName} {onlineOperCount} :operator(s) online"
  part[2] = fmt":{sName} 253 {uName} {unknownConnectionCount} :unknown connection(s)"
  part[3] = fmt":{sName} 254 {uName} {channelCount} :channels formed"
  part[4] = fmt":{sName} 255 {uName} :I have {userCount} clients and {serverCount} servers"
  
  for line in part:
    discard sendClient(c, line)

# sendMotd
# Sends the MOTD to a connected client
proc sendMotd*(c: Client) {.async.} =
  let filename = "../data/motd.txt"
  let file = open(filename)

  let sName = getPrimaryIPAddr()
  let uName = c.nickname
  let mStart = fmt":{sName} 375 {uName} :- {sName} Message of the Day -"
  let mEnd = fmt":{sName} 376 {uName} :End of /MOTD command."

  discard sendClient(c, mStart)
  if file.isNil:
    echo "Failed to load MOTD file."
    let errResp = fmt":{sName} 422 {uName} :MOTD File is missing"
    discard sendClient(c, errResp)
  else:
    for line in lines(file):
      discard sendClient(c, line)

    discard sendClient(c, mEnd)
    close(file)

proc clientErr*(c: Client, err: ErrorReply, text: string) {.async.} =
  await c.socket.send("Error: " & $int(err) & " " & text & "\c\L")

proc errAlreadyRegistered*(c: Client) =
  discard clientErr(c, ERR_ALREADYREGISTRED, "User already registered")

proc errNeedMoreParams*(c: Client) =
  discard clientErr(c, ERR_NEEDMOREPARAMS, "Need more parameters")

proc removeClientbyIp*(ip: string) =
  var toRem: Client

  for a in s.clients:
    if a.ipAddr == ip:
      toRem = a
  
  if toRem != nil:
    s.clients.delete(s.clients.find(toRem))

# getClientbyNickname
# Finds a connected client by nickname
proc getClientbyNickname*(nick: string): Client =
  for a in s.clients:
    if a.nickname == nick:
      return a
  return nil

proc removeClientbyNickname*(nick: string) =
  var toRem: Client

  for a in s.clients:
    if a.nickname == nick:
      toRem = a
  
  if toRem != nil:
    s.clients.delete(s.clients.find(toRem))

# getChannelByName
# Finds a channel on the server
proc getChannelByName*(name: string): ChatChannel =
  for a in s.channels:
    if a.name == name:
      return a
  return nil

# isClientInChannel
# Finds a client in a channel
proc isClientInChannel*(channel: string, nickname: string): bool =
  for a in s.channels:
    for b in a.clients:
      if b.nickname == nickname:
        return true
  return false