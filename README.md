# Communicator
Communicator is a re-written version of the original RPCore that was used with the PDA Addon in WildStar.
The new version has been tuned for Drop 5, and keeps the Queue's that were in place for properly handling
the messages.

Changes to the ICommLib, require us to change the way the library is initialized and how information is
being parsed. This requires proper serialization and de-serialization of the messages being sent over the
channel.

Outside that, the way Communicator works is almost the same as the way RPCore worked, and used the same
interface and types. Only the serialization of the messages is different, rending any compatibility between
them useless.

# Usage