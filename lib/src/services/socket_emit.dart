import '../pages/home/home_page.dart';

class SocketEmit {
  sendSdpForBroadcase(String sdp, String roomId) {
    socket.emit('SEND-CSS', {'sdp': sdp, 'roomId' : roomId});
  }

  sendSdpForReceive(String sdp, String socketId, String roomId) {
    socket.emit('RECEIVE-CSS', {
      'sdp': sdp,
      'socketId': socketId,
      'roomId' : roomId
    });
  }

  sendSdpForOut(String roomId) {
    socket.emit('OUT-CSS',
        {
          'roomId' : roomId
        }
        );
  }
}
