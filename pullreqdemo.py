"""
Demo File for Pull Requests

"""

import os, sys

def filetest(name='default.txt'):
    f = open(name,rw)
    print f
    f.close()
    
if __name__ == '__main__':
    filetest(sys.argv[1])

    
#We need a default.txt file in repo at some point)
