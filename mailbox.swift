
import Foundation

// Used to connect concurrent threads and communicate values across them.
// For more info, visit https://gobyexample.com/channels
class Mailbox<T> {
    
    // Signals--communicating mailbox and delivery status between threads
    let mailboxNotFull: dispatch_queue_t
    let messageSent: dispatch_queue_t
    let messageReceived: dispatch_queue_t
    
    // Locks--syncronizing blocks of code so that only one thread can perform
    //        a given action at a time, preventing state corruption
    let receiveMessage = dispatch_semaphore_create(1)
    let sendMessage = dispatch_semaphore_create(1)
    let openMailbox = dispatch_semaphore_create(1)

    // Stores messages in transit between threads
    var mailbox = [T]()
    
    // Maximum number of messages that can be stored in our given mailbox at
    // a time before we start blocking threads
    let capacity: Int
    
    // Capacity argument specifies the number of messages that can be sent,
    // unreceieved, before sending starts to block the thread. By default,
    // the capacity is 0, and every sent message is blocking until it is
    // received.`
    init(capacity: Int = 0) {
        assert(capacity >= 0, "Channel capacity must be a positive value")
        self.capacity = capacity
        
        // Keeps track of how much space is left in our mailbox so that
        // only add new values when there is enough space. Our mailbox can hold
        // one more than capacity messages because we need to hold also hold the
        // message currently in transit.
        self.mailboxNotFull = dispatch_semaphore_create(capacity + 1)
        
        // Notifies the recipient when a message has been sent so that it can
        // pick it up. If multiple messages are sent without being received,
        // these notifcations to the recipient pile up, waiting.
        self.messageSent = dispatch_semaphore_create(0)
        
        // Keeps track of how many messages in our mailbox are still waiting to
        // be received. This allows us to block the thread when our mailbox is
        // over capacity and unblock it once a message has been received so we
        // are again at normal capacity.
        self.messageReceived = dispatch_semaphore_create(capacity)
    }
    
    func send(message: T) {
        // Wait in the line to send your message.
        dispatch_semaphore_wait(sendMessage, DISPATCH_TIME_FOREVER)

        // Wait until there is space in the mailbox to store your message.
        dispatch_semaphore_wait(mailboxNotFull, DISPATCH_TIME_FOREVER)

        // Claim the mailbox once it's not in use, and store your message in it.
        dispatch_semaphore_wait(openMailbox, DISPATCH_TIME_FOREVER)
        mailbox.append(message)
        dispatch_semaphore_signal(openMailbox) // Close the mailbox

        // Let the recipient know that there is a message waiting for them.
        dispatch_semaphore_signal(messageSent)
        
        // If the mailbox too full, don't leave your message unattended
        // until another message is received first.
        dispatch_semaphore_wait(messageReceived, DISPATCH_TIME_FOREVER)
        
        // You sent your message, so get out of line and let the next thread
        // send its mail!
        dispatch_semaphore_signal(sendMessage)
    }
    
    func receive() -> T {
        // Wait in the line to receive you message.
        dispatch_semaphore_wait(receiveMessage, DISPATCH_TIME_FOREVER)
        
        // Wait until somebody sends a message so that there's a message
        // available for you in the mailbox.
        dispatch_semaphore_wait(messageSent, DISPATCH_TIME_FOREVER)
        
        // Claim the mailbox once it's not in use, and grab your message from it.
        dispatch_semaphore_wait(openMailbox, DISPATCH_TIME_FOREVER)
        let message = mailbox.removeAtIndex(0)
        dispatch_semaphore_signal(openMailbox) // Close the mailbox

        // Signal that the mailbox is no longer full (as we just removed a
        // message from it) so that senders can put more messages in it.
        dispatch_semaphore_signal(mailboxNotFull)
        
        // Signal that the mailbox is no longer too full so that any other poor
        // thread waiting next to it can finally insert his message and leave.
        dispatch_semaphore_signal(messageReceived)
        
        // You received your message, so get out of line and let the next thead
        // retrieve its mail!
        dispatch_semaphore_signal(receiveMessage)
        
        return message
    }
}

// Custom operators for sending and recieving mail.
prefix operator <- { }
infix operator <- { }
prefix func <-<T>(rhs: Channel<T>) -> T { return rhs.receive() }
func <-<T>(lhs: Channel<T>, rhs: T) { return lhs.send(rhs) }

// Calls the passed in function or closure on a background thread. Equivalent
// to Go's "go" keyword.
func dispatch(routine: () -> ()) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), routine)
}

// Calls the passed in function or closure on the main thead. Important for
// UI work!
func main(routine: () -> ()) {
    dispatch_async(dispatch_get_main_queue(), routine)
}
