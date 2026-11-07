import os, signal, sys
signal.signal(signal.SIGINT, signal.SIG_DFL)
os.setsid()
os.execvp("sh", ["sh", sys.argv[1], "side"])
