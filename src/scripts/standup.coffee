# Agile standup bot ala tender
#
# hubot standup for <team> - Start a standup for the team
# hubot next - I'm done, go to the next person
# hubot skip <name> - Skip someone when they're offline
# hubot cancel standup - Cancel the current standup

module.exports = (robot) ->
  robot.respond /(?:cancel|stop) standup *$/i, (msg) ->
    delete robot.brain.data.standup?[msg.message.user.room]
    msg.send "Standup cancelled"

  robot.respond /standup for (.*) *$/i, (msg) ->
    room  = msg.message.user.room
    group = msg.match[1].trim()
    if robot.brain.data.standup?[room]
      msg.send "The standup for #{robot.brain.data.standup[room].group} is in progress! Cancel it first with 'cancel standup'"
      return

    attendees = []
    for own key, user of robot.brain.data.users
      roles = user.roles or [ ]
      if "a #{group} member" in roles or "an #{group} member" in roles or "a member of #{group}" in roles
        attendees.push user
    if attendees.length > 0
      robot.brain.data.standup or= {}
      robot.brain.data.standup[room] = {
        group: group,
        start: new Date().getTime(),
        attendees: attendees,
        remaining: shuffleArrayClone(attendees)
        log: [],
      }
      who = (user.name for user in attendees).join(', ')
      msg.send "Ok, let's start the standup: #{who}"
      nextPerson robot, room, msg
    else
      msg.send "Oops, can't find anyone with 'a #{group} member' role!"

  robot.respond /(?:that\'s it|next(?: person)?|done) *$/i, (msg) ->
    unless robot.brain.data.standup?[msg.message.user.room]
      return
    if robot.brain.data.standup[msg.message.user.room].current.name != msg.message.user.name
      msg.send "#{addressUser(msg.message.user.name, robot.adapter)} but it's not your turn! Use skip instead."
    else
      nextPerson robot, msg.message.user.room, msg

  robot.respond /skip (.*) *$/i, (msg) ->
    unless robot.brain.data.standup?[msg.message.user.room]
      return

    users = robot.usersForFuzzyName msg.match[1]
    if users.length is 1
      skip = users[0]
      standup = robot.brain.data.standup[msg.message.user.room]
      standup.remaining = (user for user in standup.remaining when user.name != skip.name)
      if standup.current.name == skip.name
        nextPerson robot, msg.message.user.room, msg
      else
        msg.send "Ok, I will skip #{skip.name}"
    else if users.length > 1
      msg.send "Be more specific, I know #{users.length} people named like that: #{(user.name for user in users).join(", ")}"
    else
      msg.send "#{msg.match[1]}? Never heard of 'em"

  robot.catchAll (msg) ->
    unless robot.brain.data.standup?[msg.message.user.room]
      return
    robot.brain.data.standup[msg.message.user.room].log.push { message: msg.message, time: new Date() }

shuffleArrayClone = (array) ->
  cloned = []
  for i in (array.sort -> 0.5 - Math.random())
    cloned.push i
  cloned

nextPerson = (robot, room, msg) ->
  standup = robot.brain.data.standup[room]
  if standup.remaining.length == 0
    howlong = calcMinutes(new Date().getTime() - standup.start)
    msg.send "All done! Standup was #{howlong}."
    delete robot.brain.data.standup[room]
  else
    standup.current = standup.remaining.pop()
    msg.send "#{addressUser(standup.current.name, robot.adapter)} your turn"

addressUser = (name, adapter) ->
  className = adapter.__proto__.constructor.name
  switch className
    when "HipChat" then "@\"#{name}\""
    else "#{name}:"

calcMinutes = (milliseconds) ->
  seconds = Math.floor(milliseconds / 1000)
  if seconds > 60
    minutes = Math.floor(seconds / 60)
    seconds = seconds % 60
    "#{minutes} minutes and #{seconds} seconds"
  else
    "#{seconds} seconds"
