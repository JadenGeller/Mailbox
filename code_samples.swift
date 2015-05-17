//
//  main.swift
//  Go routine
//
//  Created by Jaden Geller on 5/17/15.
//  Copyright (c) 2015 Jaden Geller. All rights reserved.
//

import Foundation

func runWorker() {
    func worker(done: Mailbox<Bool>) {
        println("Working...")
        sleep(1)
        println("Done!")
        
        done <- true
    }
    
    let done = Mailbox<Bool>()
    dispatch { worker(done) }
    <-done
}

func runPingPong() {
    
    func ping<M : OutgoingMailboxType where M.Message == String>(pings: M, message: String) {
        pings <- message
    }
    
    func pong<M : IncomingMailboxType, N : OutgoingMailboxType where M.Message == String, N.Message == String>(pings: M, pongs: N) {
        let message = <-pings
        pongs <- message
    }
    
    let pings = Mailbox<String>(capacity: 1)
    let pongs = Mailbox<String>(capacity: 1)
    
    ping(pings, "Greetings, world!")
    pong(pings, pongs)
    
    println(<-pongs)
    
}

func runClosable() {
    
    let jobs = ClosableMailbox<Int>(capacity: 5)
    let done = Mailbox<Bool>(capacity: 1)
    
    dispatch {
        for j in jobs {
            println("Received job \(j)")
        }
        println("Received all jobs!")
        
        done <- true
    }
    
    for j in 1...3 {
        jobs <- j
    }
    jobs.close()
    <-done
    
}

func runRange() {
    
    let queue = ClosableMailbox<String>(capacity: 2)
    queue <- "one"
    queue <- "two"
    queue.close()
    
    for x in queue {
        println(x)
    }
    
}

func runPool() {
    
    let jobs = ClosableMailbox<Int>(capacity: 100)
    let results = ClosableMailbox<Int>(capacity: 100)
    
    for w in 1...3 {
        dispatch {
            for j in jobs {
                sleep(UInt32(j))
                println("Worker \(w) processing job \(j)")
                results <- j
            }
        }
    }
    
    for j in [1,3,4,1,5,8,3] {
        jobs <- j
    }
    jobs.close()
    
    for _ in results { }
    
}

