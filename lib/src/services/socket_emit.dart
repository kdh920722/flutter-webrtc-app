import '../pages/home/home_page.dart';

class SocketEmit {
  sendInitPeer(String sdp, String userId, String roomId) {
    socket.emit('INIT_PEER_REQ', {'sdp': sdp, 'userId' : userId, 'roomId' : roomId});
  }

  sendReceivePeer(String sdp, String userId, String otherUserId, String roomId) {
    socket.emit('RECEIVE_PEER_REQ', {'sdp': sdp, 'userId' : userId, 'otherUserId': otherUserId, 'roomId' : roomId});
  }
}
