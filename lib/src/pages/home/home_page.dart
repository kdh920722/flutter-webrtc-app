import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as RTC;
import 'package:flutter_webrtc_app/src/pages/home/widgets/remote_view_card.dart';
import 'package:sdp_transform/sdp_transform.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:flutter/foundation.dart' as foundation;
import '../../services/socket_emit.dart';

bool isConnected = false;
bool isAudioOn = true, isVideoOn = true;
bool isScreenShareOn = false;
String roomId = "";
String myId = "";

Map<String, dynamic> configuration = {
  'iceServers': [
    {"urls" : "stun:stun.stunprotocol.org",},
    {"urls" : "stun:stun.l.google.com:19302",},
    {"urls" : "stun:stun1.l.google.com:19302",},
    {"urls" : "stun:stun2.l.google.com:19302",},
    {"urls" : "stun:stun3.l.google.com:19302",},
    {"urls" : "stun:stun4.l.google.com:19302",},
    {"urls" : "stun:stun.voippro.com:3478",},
    {"urls" : "stun:stun.voipraider.com:3478",},
    {"urls" : "stun:stun.voipstunt.com:3478",},
    {"urls" : "stun:stun.voipwise.com:3478",},
    {"urls" : "stun:stun.voipzoom.com:3478",},
    {"urls" : "stun:stun.vopium.com:3478",},
    {"urls" : "stun:stun.voxgratia.org:3478",},
    {"urls" : "stun:stun.voxox.com:3478",},
    {"urls" : "stun:stun.voys.nl:3478",},
    {"urls" : "stun:stun.voztele.com:3478",},
    {"urls" : "stun:stun.vyke.com:3478",},
    {"urls" : "stun:stun.webcalldirect.com:3478",},
    {"urls" : "stun:stun.whoi.edu:3478",},
    {"urls" : "stun:stun.wifirst.net:3478",},
    {"urls" : "stun:stun.wwdl.net:3478",},
    {"urls" : "stun:stun.xs4all.nl:3478",},
    {"urls" : "stun:stun.xtratelecom.es:3478",},
    {"urls" : "stun:stun.yesss.at:3478",},
    {"urls" : "stun:stun.zadarma.com:3478",},
    {"urls" : "stun:stun.zadv.com:3478",},
    {"urls" : "stun:stun.zoiper.com:3478",}
    /*
    {
      "urls": "turn:turn.jacknathan.tk:3478",
      "username": "ducanhzed",
      "credential": "1507200a",
    },
     */
  ],
 // 'sdpSemantics': "unified-plan",
};

late Socket socket;

class HomePage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver{
  List<Map<String, dynamic>> socketIdRemotes = [];
  List<Map<String, String>> socketMessages = [];
  RTC.RTCPeerConnection? _peerConnection;
  RTC.MediaStream? _localStream;
  RTC.MediaStream? _localScreenStream;
  final RTC.RTCVideoRenderer _localRenderer = RTC.RTCVideoRenderer();
  bool _isSend = false;
  bool _isFrontCamera = true;
  bool get isiOS => foundation.defaultTargetPlatform == foundation.TargetPlatform.iOS;
  bool get isAndroid => foundation.defaultTargetPlatform == foundation.TargetPlatform.android;
  final roomIdTextEditingController = TextEditingController();
  final messageTextEditingController = TextEditingController();
  final messageListViewController = ScrollController();

  @override
  void initState() {
    print("[KDH] ====================> initState ");
    super.initState();
  }

  @override
  void dispose() {
    print("[KDH] ====================> dispose ");
    myId = "";
    roomId = "";
    isConnected = false;
    isScreenShareOn = false;
    socket.disconnect();
    socket.dispose();
    socketIdRemotes.clear();
    roomIdTextEditingController.dispose();
    messageTextEditingController.dispose();
    messageListViewController.dispose();
    _peerConnection?.close();
    _localStream?.dispose();
    _localScreenStream?.dispose();
    _localRenderer.dispose();
    _isSend = false;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        print("[KDH] ====================> resumed ");
        break;
      case AppLifecycleState.inactive:
        print("[KDH] ====================> inactive ");
        break;
      case AppLifecycleState.detached:
        print("[KDH] ====================> detached ");
        // DO SOMETHING!
        break;
      case AppLifecycleState.paused:
        print("[KDH] ====================> paused ");
        break;
      default:
        break;
    }
  }

  _init(){
    connectAndListen();
  }

  _switchCamera() async {
    final localStream = _localStream;
    if (localStream != null) {
      bool value = await localStream.getVideoTracks()[0].switchCamera();
      while (value == _isFrontCamera) {
        value = await localStream.getVideoTracks()[0].switchCamera();
      }
      _isFrontCamera = value;
      setState(() {});
    }
  }

  _createPeerConnectionAnswer(socketId, index) async {
    RTC.RTCPeerConnection pc = await RTC.createPeerConnection(configuration);

    pc.onTrack = (track) {
      socketIdRemotes[index]['stream'].srcObject = track.streams[0];
      setState(() {});
    };

    pc.onRenegotiationNeeded = () {
      _createOfferForReceive(socketId);
    };

    return pc;
  }

  void connectAndListen() async {
    var urlConnectSocket = 'http://192.168.0.29:5000';
    socket = io(urlConnectSocket, OptionBuilder().enableForceNew().setTransports(['websocket']).build());
    socket.connect();
    socket.onConnect((_) {
      socket.on('CONNECTED_ID', (data) async {
        myId = data['socketId'];
        roomIdTextEditingController.text = "";
        messageTextEditingController.text = "";
        initRenderers();
        _createPeerConnection().then((pc) async {
            _peerConnection = pc;
            _localStream = await _getUserMedia();
            _localStream?.getTracks().forEach((track) {
              _peerConnection?.addTrack(track, _localStream!);
            });
            isConnected = true;
            setState(() {});
          },
        );
      });

      socket.on('INIT_PEER_RESP', (data) async {
        List<String> listSocketId = (data['sockets'] as List<dynamic>).map((e) => e.toString()).toList();
        await Future.forEach(listSocketId, (element) async {
          print("[KDH] ====================> init peer add other users $element");
          RTC.RTCVideoRenderer stream = RTC.RTCVideoRenderer();
          await stream.initialize();
          socketIdRemotes.add({
            'socketId': element,
            'pc': null,
            'stream': stream,
          });
          print("[KDH] ====================> init peer add other users ${socketIdRemotes.length}");
          setState(() {});
        });
        listSocketId.asMap().forEach((index, otherUser) async {
          _createPeerConnectionAnswer(otherUser, index).then((pcRemote) {
            print("[KDH] ====================> init peer pc answer $index");
            socketIdRemotes[index]['pc'] = pcRemote;
            socketIdRemotes[index]['pc'].addTransceiver(
                kind: RTC.RTCRtpMediaType.RTCRtpMediaTypeVideo,
                init: RTC.RTCRtpTransceiverInit(direction: RTC.TransceiverDirection.RecvOnly)
            );
            setState(() {});
          });
        });
        _setRemoteDescription(data['sdp']);
      });

      socket.on('INIT_NEW_PEER_RESP', (data) async {
        String newUser = data['socketId'];
        print("[KDH] ====================> newUser $newUser");
        RTC.RTCVideoRenderer stream = RTC.RTCVideoRenderer();
        await stream.initialize();
        socketIdRemotes.add({
          'socketId': newUser,
          'pc': null,
          'stream': stream,
        });
        setState(() {});
        int newUserIndex = socketIdRemotes.length - 1;
        _createPeerConnectionAnswer(newUser, newUserIndex).then((pcRemote) {
          print("[KDH] ====================> new peer pc answer $newUserIndex");
          socketIdRemotes[newUserIndex]['pc'] = pcRemote;
          socketIdRemotes[newUserIndex]['pc'].addTransceiver(
            kind: RTC.RTCRtpMediaType.RTCRtpMediaTypeVideo,
            init: RTC.RTCRtpTransceiverInit(direction: RTC.TransceiverDirection.RecvOnly)
          );
          setState(() {});
        });
      });

      socket.on('RECEIVE_PEER_RESP', (data) {
        int index = socketIdRemotes.indexWhere((element) => element['socketId'] == data['socketId']);
        if (index != -1) {
          print("[KDH] ====================> receive sdp $index");
          _setRemoteDescriptionForReceive(index, data['sdp']);
        }
        setState(() {});
      });

      socket.on('MESSAGE_PEER_RESP', (data) {
        String senderId = data['socketId'];
        String senderMessage = data['message'];
        print("[KDH] ====================> message senderId $senderId");
        print("[KDH] ====================> message senderMessage $senderMessage");
        socketMessages.add({
          'senderId': senderId,
          'senderMessage': senderMessage,
        });
        setState(() {});
      });

      socket.on('OUT_PEER_RESP', (data) {
        String outUser = data['socketId'];
        int index = socketIdRemotes.indexWhere((item) => item['socketId'] == outUser);
        if (index != -1) {
          socketIdRemotes.removeAt(index);
          setState(() {});
        }
      });
    });
    // onConnected

    socket.onDisconnect((_){
      _endCall();
    });
  }

  initRenderers() async {
    await _localRenderer.initialize();
  }

  void _setRemoteDescription(sdp) async {
    RTC.RTCSessionDescription description = RTC.RTCSessionDescription(sdp, 'answer');
    await _peerConnection?.setRemoteDescription(description);
  }

  void _setRemoteDescriptionForReceive(indexSocket, sdp) async {
    RTC.RTCSessionDescription description = RTC.RTCSessionDescription(sdp, 'answer');
    await socketIdRemotes[indexSocket]['pc'].setRemoteDescription(description);
  }

  _createOffer() async {
    RTC.RTCSessionDescription? description = await _peerConnection?.createOffer({
      'offerToReceiveVideo': true,
      'offerToReceiveAudio': true,
    });
    _peerConnection?.setLocalDescription(description!);
    var session = parse(description!.sdp.toString());
    String sdp = write(session, null);
    await sendInitPeer(sdp);
  }

  _createOfferForReceive(String otherUserId) async {
    int index = socketIdRemotes.indexWhere((item) => item['socketId'] == otherUserId);
    if (index != -1) {
      RTC.RTCSessionDescription description = await socketIdRemotes[index]['pc'].createOffer();
      socketIdRemotes[index]['pc'].setLocalDescription(description);
      var session = parse(description.sdp.toString());
      String sdp = write(session, null);
      await sendReceivePeer(sdp, myId, otherUserId);
    }
  }

  _createPeerConnection() async {
    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory": {
        "OfferToReceiveAudio": true,
        "OfferToReceiveVideo": true,
      },
      "optional": [],
    };

    RTC.RTCPeerConnection pc = await RTC.createPeerConnection(configuration, offerSdpConstraints);

    pc.onRenegotiationNeeded = () {
      if (!_isSend) {
        _isSend = true;
        _createOffer();
      }
    };
    return pc;
  }

  Future<void> startScreenSharing() async {
    final mediaConstraints = <String, dynamic>{'audio': true, 'video': true};

    try {
      var stream = await RTC.navigator.mediaDevices.getDisplayMedia(mediaConstraints);
      _localStream = stream;
      _localRenderer.srcObject = _localStream;

    } catch (e) {
      print(e.toString());
    }
  }

  void stopScreenSharing() {
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream = null;
  }

  Future sendInitPeer(
    String sdp,
  ) async {
    SocketEmit().sendInitPeer(sdp, myId, roomId);
  }

  Future sendReceivePeer(
    String sdp,
    String userId,
    String otherUserId,
  ) async {
    SocketEmit().sendReceivePeer(sdp, userId, otherUserId, roomId);
  }

  Future sendMessagePeer(
      String userId,
      String message
      ) async {
    print("[KDH] ====================> SEND MESSAGE");
    SocketEmit().sendMessagePeer(userId, roomId, message);
  }

  _sendOutPeer() async {
    _endCall();
  }

  _getUserMedia() async {
    RTC.MediaStream stream = await RTC.navigator.mediaDevices.getUserMedia({
      'audio': {
        'sampleRate': 16000,
        'sampleSize': 16,
        'volume': 0.3,
        'echoCancellation': false,
        'noiseSuppression': false,
        'autoGainControl': true
    },
      'video': {
        'facingMode': 'user',
      },
    });


    _localRenderer.srcObject = stream;
    setState(() {});

    return stream;
  }

  _endCall() {
    socket.disconnect();
    _peerConnection?.close();
    socketIdRemotes.clear();
    socketMessages.clear();
    _isSend = false;
    myId = "";
    roomId = "";
    isAudioOn = true;
    isVideoOn = true;
    isConnected = false;
    isScreenShareOn = false;
    setState((){});
  }

  _toggleMic() {
    // change status
    isAudioOn = !isAudioOn;
    // enable or disable audio track
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = isAudioOn;
    });
    setState(() {});
  }

  _toggleScreenShare(){
    _toggleCamera();
    if(isVideoOn){
      stopScreenSharing();
    }else{
      startScreenSharing();
    }
    setState(() {});
  }

  _toggleCamera() {
    // change status
    isVideoOn = !isVideoOn;
    // enable or disable video track
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = isVideoOn;
    });
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double w = MediaQuery.of(context).size.width - MediaQuery.of(context).padding.left - MediaQuery.of(context).padding.right;
    double h = MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom;

    if(messageListViewController.positions.isNotEmpty){
      SchedulerBinding.instance.addPostFrameCallback((_) {
        messageListViewController.jumpTo(messageListViewController.position.maxScrollExtent);
      });
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.amber,
        toolbarHeight: 60,
        elevation: 5,
        title:  const Text('META CALL', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: Container(
        color: Colors.black,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Stack(
              children: [
                !isConnected
                    ? Container(
                  color: Colors.black,
                  width: w,
                  height: 200,
                  child: socketIdRemotes.isEmpty
                      ? Container()
                      : RemoteViewCard(
                          remoteRenderer: socketIdRemotes[0]['stream'],
                        ),
                ) : Container(
                  color: Colors.black,
                  width: w,
                  height: h-60,
                  child: socketIdRemotes.isEmpty
                      ? Container()
                      : RemoteViewCard(
                    remoteRenderer: socketIdRemotes[0]['stream'],
                  ),
                ),
                Positioned(
                  bottom: 50.0,
                  left: 12.0,
                  right: 0,
                  child: Container(
                    color: Colors.transparent,
                    width: size.width,
                    height: size.width * .35,
                    child: socketIdRemotes.length < 2
                        ? Container()
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: socketIdRemotes.length - 1,
                            itemBuilder: (context, index) {
                              return Container(
                                margin: EdgeInsets.only(right: 6.0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4.0),
                                  border: Border.all(
                                    color: Colors.amberAccent,
                                    width: 2.0,
                                  ),
                                ),
                                child: RemoteViewCard(
                                  remoteRenderer: socketIdRemotes[index + 1]['stream'],
                                ),
                              );
                            },
                          ),
                  ),
                ),
                Positioned(
                  top: 45.0,
                  right: 15.0,
                  child: !isConnected
                      ? Container() : Container(
                    width: size.width * .35,
                    height: size.width* .56,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(4.0),
                      border: Border.all(
                        color: Colors.amberAccent,
                        width: 2.0,
                      ),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.start, children: [
                      Container(color: Colors.white12, height: size.width* .56 * .8, child:
                      socketMessages.isEmpty
                          ? Container() : ListView.builder(
                        controller: messageListViewController,
                        scrollDirection: Axis.vertical,
                        itemCount: socketMessages.length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 2.0),
                            child: Text("${socketMessages[index]['senderId']!.substring(0,5)} : ${socketMessages[index]['senderMessage']!}",
                                style: const TextStyle(fontSize: 10, color: Colors.white)),
                          );
                        },
                      ),
                      ),
                      Container(height: size.width* .56 * .18, child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(height: size.width* .56 * .18, width: size.width * .35 * .55, child:
                        TextField(
                          controller: messageTextEditingController,
                          style: const TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                          cursorColor: Colors.grey,
                          decoration: InputDecoration(
                            hintText: "대화입력",
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 10),
                            alignLabelWithHint: true,
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.transparent),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.transparent),
                            ),
                          ),
                        ),
                        ),
                        SizedBox(width: size.width * .35 * .07),
                        SizedBox(height: size.width* .56 * .18, width: size.width * .35 * .35, child:
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder( //to set border radius to button
                                  borderRadius: BorderRadius.circular(1)
                              ),
                              backgroundColor: Colors.amber
                          ),
                          child: const Text(
                            "전송",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.black,
                            ),
                          ),
                          onPressed: () {
                            if(messageTextEditingController.text.trim() != ""){
                              String message = messageTextEditingController.text;
                              sendMessagePeer(myId, message);
                              messageTextEditingController.text = "";
                            }
                          },
                        )
                        ),
                      ])
                      ),
                    ])
                  )
                ),
                Positioned(
                  top: 45.0,
                  left: 15.0,
                  child: Row(
                    children: [
                      !isConnected
                          ? Container(
                              height: 150,
                              width: w-30,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                               children: [
                                 TextField(
                                   style: const TextStyle(color: Colors.grey),
                                   controller: roomIdTextEditingController,
                                   textAlign: TextAlign.center,
                                   cursorColor: Colors.grey,
                                   decoration: InputDecoration(
                                     focusedBorder: OutlineInputBorder(
                                         borderSide: const BorderSide(color: Colors.amber),
                                         borderRadius: BorderRadius.circular(10.0)
                                     ),
                                     enabledBorder: OutlineInputBorder(
                                       borderSide: const BorderSide(color: Colors.amber),
                                       borderRadius: BorderRadius.circular(10.0)
                                     ),
                                     hintText: "방 ID",
                                     hintStyle: const TextStyle(color: Colors.grey),
                                     alignLabelWithHint: true,
                                     border: OutlineInputBorder(
                                       borderRadius: BorderRadius.circular(20.0),
                                     ),
                                   ),
                                 ),
                                 SizedBox(height: 5.0),
                                 ElevatedButton(
                                   style: ElevatedButton.styleFrom(
                                       fixedSize: Size(w-30,60),
                                       shape: RoundedRectangleBorder( //to set border radius to button
                                           borderRadius: BorderRadius.circular(10)
                                       ),
                                       backgroundColor: Colors.amber
                                   ),
                                   child: const Text(
                                     "입장하기",
                                     style: TextStyle(
                                       fontSize: 14,
                                       color: Colors.black,
                                     ),
                                   ),
                                   onPressed: () {
                                     if(roomIdTextEditingController.text.trim() != ""){
                                       roomId = roomIdTextEditingController.text;
                                       _init();
                                     }
                                   },
                                 )
                               ],
                              ),
                            )
                          : FittedBox(
                              fit: BoxFit.cover,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.all(Radius.circular(6.0)),
                                  border: Border.all(color: Colors.amberAccent, width: 2.0),
                                ),
                                child: RemoteViewCard(
                                  remoteRenderer: _localRenderer,
                                ),
                              ),
                            ),
                      !isConnected
                          ? Container() : SizedBox(width: 8.0),
                      !isConnected
                          ? Container() : Column(
                        children: [
                          GestureDetector(
                            onTap: () => _switchCamera(),
                            child: Container(
                              height: size.width * .125,
                              width: size.width * .125,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.amberAccent, width: 2.0),
                                color: Colors.amberAccent,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.switch_camera,
                                color: Colors.black,
                                size: size.width / 18.0,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 8.0,
                          ),
                          GestureDetector(
                            onTap: () => _toggleMic(),
                            child: Container(
                              height: size.width * .125,
                              width: size.width * .125,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.amberAccent, width: 2.0),
                                color: Colors.amberAccent,
                              ),
                              alignment: Alignment.center,
                              child: Icon(isAudioOn ? Icons.mic : Icons.mic_off,
                                color: Colors.black,
                                size: size.width / 18.0)
                            ),
                          ),
                          !isScreenShareOn? Container() : SizedBox(
                            height: 8.0,
                          ),
                          !isScreenShareOn? Container() : GestureDetector(
                            onTap: () => _toggleScreenShare(),
                            child: Container(
                                height: size.width * .125,
                                width: size.width * .125,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.amberAccent, width: 2.0),
                                  color: Colors.amberAccent,
                                ),
                                alignment: Alignment.center,
                                child: Icon(Icons.monitor, color: Colors.black, size: size.width / 18.0)
                            ),
                          ),
                          SizedBox(
                            height: 8.0,
                          ),
                          GestureDetector(
                            onTap: () => _sendOutPeer(),
                            child: Container(
                                height: size.width * .125,
                                width: size.width * .125,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.black, width: 2.0),
                                  color: Colors.black,
                                ),
                                alignment: Alignment.center,
                                child: Icon(Icons.logout,
                                    color: Colors.amberAccent,
                                    size: size.width / 18.0)
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
