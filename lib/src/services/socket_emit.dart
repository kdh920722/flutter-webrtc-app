import '../pages/home/home_page.dart';

class SocketEmit {
  sendInitPeer(String sdp, String userId, String roomId) {
    socket.emit('INIT_PEER_REQ', {'sdp': sdp, 'userId' : userId, 'roomId' : roomId});
  }

  sendReceivePeer(String sdp, String userId, String otherUserId, String roomId) {
    socket.emit('RECEIVE_PEER_REQ', {'sdp': sdp, 'userId' : userId, 'otherUserId': otherUserId, 'roomId' : roomId});
  }

  sendMessagePeer(String userId, String roomId, String message) {
    print("[KDH] ====================> SEND MESSAGE 2");
    socket.emit('MESSAGE_PEER_REQ', {'userId' : userId, 'roomId' : roomId, 'message' : message});
  }
}
