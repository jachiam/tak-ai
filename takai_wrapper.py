#	NOTES:
#	This is an almost exact copy of Chaitanya Vadrevu's ShlktBot wrapper!
#	I have made only very minor modifications to hook this up to my AI.
#	As a result, I can take no credit for this code.
#
#	Chaitanya's original code can be found here:
#	https://github.com/chaitu236/ShlktBot-wrapper
#
#	Also, make sure to check out Chaitanya's PlayTak.com website!
#
#	- Josh Achiam

import subprocess
import socket
import re
import argparse
import sys
import sched, time
from threading import Thread
from time import sleep
from socket import error as socket_error

sock=None
gameno=''
args=''
sc=None
connected=False

debug = True

def read_line():
  data=''
  global sock
  while True:
    c = sock.recv(1)
    if len(c) == 0:
      sock = None
      connected = False
      print 'Connection closed by server. Waiting 30 seconds before re-connecting'
      time.sleep(30)
      thread.exit()
    if c=='\n' or c=='':
      break
    else:
      data += c
  if debug and data!="OK":
    print '= '+data
  return data

def send(msg):
  global sock
  if debug and msg!="PING":
    print '* '+msg
  try:
    if sock != None and connected:
      sock.sendall(msg+'\n')
    else:
      print 'Not sending since sock=None or not connected ', sock, connected
  except socket_error as e:
    print 'Socket error when trying to send ', e, sock, connected

def post_seek(size, time):
  send('Seek '+str(size)+' '+str(time))

def bot_to_server(move):
  move = move.strip()
  #[T0, X]: ai move => c3
  move = move.split(' ')[2][:-1]
  match = re.match(r'f?[a-h][1-8]$', move)
  if match:
    return 'P '+move[1:].upper()
  match = re.match(r'c([a-h][1-8])$', move)
  if match:
    return 'P '+match.group(1).upper()+' C'
  match = re.match(r's([a-h][1-8])$', move)
  if match:
    return 'P '+match.group(1).upper()+' W'

  match = re.match(r'([1-8])?([a-h])([1-8])([><\-+])$', move)
  if match:
    fl = ord(match.group(2))
    rw = int(match.group(3))
    sym = match.group(4)
    print 'sym='+sym

    fadd=0
    radd=0
    if sym=='<':
      fadd=-1
    elif sym =='>':
      fadd=1
    elif sym =='+':
      radd = 1
    elif sym=='-':
      radd = -1

    return 'M '+chr(fl).upper()+str(rw)+' '+chr(fl+fadd).upper()+''+str(rw+radd)+' 1'

  match = re.match(r'([1-8])([a-h])([1-8])([><\-+])([1-8]+)$', move)
  if match:
    stsz = int(match.group(1))
    fl = ord(match.group(2))
    rw = int(match.group(3))
    sym = match.group(4)
    stk = match.group(5)

    fadd=0
    radd=0
    if sym=='<':
      fadd=-1*len(stk)
    elif sym =='>':
      fadd=1*len(stk)
    elif sym =='+':
      radd = 1*len(stk)
    elif sym=='-':
      radd = -1*len(stk)

    msg = 'M '+chr(fl).upper()+str(rw)+' '+chr(fl+fadd).upper()+''+str(rw+radd)
    for i in stk:
      msg = msg+' '+i

    return msg
  return 'Not match'
  #ai move => Cb4
  print 'not implemented!!'

def wait_for_response(resp):
  k=read_line()
  while (resp not in k and "NOK" not in k):
    k=read_line()

  return k

def server_to_bot(move):
  #if 'RequestUndo' in move:
  #  return 'undo'
  spl = move.split(' ')
  #Game#1 P A4 (C|W)
  if spl[1] == 'P':
    stone=''
    if len(spl) == 4:
      if spl[3]=='W':
        stone='S'
      else:
        stone='C'
    return stone+spl[2].lower()

  #Game#1 M A2 A5 2 1
  elif spl[1] == 'M':
    fl1 = ord(spl[2][0])
    rw1 = int(spl[2][1])
    fl2 = ord(spl[3][0])
    rw2 = int(spl[3][1])

    dir=''
    if fl2==fl1:
      if rw2>rw1:
        dir='+'
      else:
        dir='-'
    else:
      if fl2>fl1:
        dir='>'
      else:
        dir='<'

    lst=''
    liftsize=0
    for i in range(4, len(spl)):
      lst = lst+spl[i]
      liftsize = liftsize+int(spl[i])

    ##there's an ambiguity here.. is the start sq. empty??.. lets find out
    #send('Game#'+gameno+' Show '+spl[2])
    #msg = wait_for_response('Game#'+gameno+' Show Sq')
    #if 'NOK' in msg:
    #  return 'Over'
    #Game#1 Show Sq [f]
    #origsq = len(msg.split(' ')[3])-2
    prefix=liftsize
    return str(prefix)+spl[2].lower()+dir+lst
  return ''

def is_white_turn(move_no):
  return (move_no%2)==0

def read_game_move(game_no):
  gm = 'Game#'+game_no
  while(True):
    msg = read_line()
    for move in ['M', 'P', 'Abandoned', 'Over', 'Show']:#, 'RequestUndo']:
      if(msg.startswith(gm+' '+move)):
        return msg

def read_bot_move(p):
  while(True):
    move = p.stdout.readline()
    print move
    if 'AI move' in move:
      return move
    elif 'Game over' in move:
      return ''

  print 'something wrong!'

"""def check_for_undo_request(game_no):
  gm = 'Game#'+game_no
  flag = True
  while(flag):
    msg = read_line()
    print 'i live here now'
    if msg.startswith(gm+' RequestUndo'):
       return msg
    if msg == '':
       return ''
"""

def bot(no, is_bot_white, size, opponent):
  p = subprocess.Popen('exec th run_AI.lua ' + str(is_bot_white) + ' ' + str(size) + ' ' + opponent,
              shell=True, bufsize=0, stdout=subprocess.PIPE, stdin=subprocess.PIPE)
  print 'color', no, 'iswhite?', is_bot_white

  breakflag = False
  move_no = 0
  while(True):
    #read from bot, write to server
    if is_white_turn(move_no) == is_bot_white:
      move=read_bot_move(p)
      if move=='':
        break;
      """msgs = check_for_undo_request(no)
      if 'RequestUndo' in msgs:
        send('Game#'+no+' RequestUndo')
        p.stdin.write('undo2\n')
        p.stdin.flush()
        move_no = move_no - 2
      else:"""
      send('Game#'+no+' '+bot_to_server(move))
    #read from server, write to bot
    else:
      print 'reading game move'
      msg = read_game_move(no)
      """if 'RequestUndo' in msg:
        send('Game#'+no+' RequestUndo')"""
      if 'Abandoned' in msg or 'Over' in msg:
        break;
      msg = server_to_bot(msg)
      if 'Over' in msg:
        break;
      print '> '+msg
      p.stdin.write(msg+'\n')
      p.stdin.flush()

    move_no = move_no+1
  p.kill()


def run():
  send('Client TakaiBot0')
  send('Login '+args.user+' '+args.password)
  line = read_line()
  if(line.startswith("Welcome")==False and line.startswith("You're already")==False):
    return #sys.exit()

  while(True):
    post_seek(args.size, args.time)
    msg=read_line()
    while(msg.startswith("Game Start")!=True):
      msg=read_line()
      if msg.startswith("Login or Register"):
        sys.exit()
      #if msg.startswith("Seek new"):
      #  spl = msg.split(' ')
      #  if spl[3] == 'TakticianBot':
      #    send('Accept ' + spl[2])

    #Game Start no. size player_white vs player_black yourcolor
    print 'game started!'+msg
    spl = msg.split(' ')
    if spl[4] == 'dove_queen' or spl[6] == 'dove_queen':
      send('Shout hi patsy :D')
      send('Shout hey everyone, this is my best friend patsy!')
    opponent = ''
    if spl[7]=="white":
      opponent = spl[6]
    else:
      opponent = spl[4]

    #send('Shout lets do our best to play a beautiful game!')
    global gameno
    gameno = spl[2]
    print 'gameno='+gameno
    bot(gameno, spl[7]=="white", args.size, opponent)
    send('Shout gg')
  send('quit')

def args():
  parser = argparse.ArgumentParser(description='This is a demo script by nixCraft.')
  parser.add_argument('-u','--user', help='User',required=True)
  parser.add_argument('-p','--password', help='Password',required=True)
  parser.add_argument('-s','--size', help='Board Size',required=True)
  parser.add_argument('-t','--time', help='Time in seconds per player',required=True)
  global args
  args = parser.parse_args()


def pinger():
  send("PING")
  sc.enter(30, 1, pinger, ())

def _startpinger():
  global sc
  sc = sched.scheduler(time.time, time.sleep)
  sc.enter(10, 1, pinger, ())
  sc.run()

def startpinger():
  thread = Thread(target = _startpinger, args=())
  thread.start()

if __name__ == "__main__":
  global sock
  args()
  server_addr = ('playtak.com', 10000)

  startpinger()

  while(True):
    try:
      sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
      sock.connect(server_addr)
      connected = True
      read_line()
      read_line()

      try:
        run()
      finally:
        sock.close()
        print 'Sleep it off.'
        time.sleep(5)
        pass

    except socket_error:
      print 'Socket error. Retrying in 10 seconds'
      time.sleep(10)
