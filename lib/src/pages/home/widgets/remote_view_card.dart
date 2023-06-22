import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as RTC;
import 'package:flutter_webrtc/flutter_webrtc.dart';

class RemoteViewCard extends StatefulWidget {
  final RTC.RTCVideoRenderer remoteRenderer;
  RemoteViewCard({
    required this.remoteRenderer,
  });

  @override
  State<StatefulWidget> createState() => _RemoteViewCardState();
}

class _RemoteViewCardState extends State<RemoteViewCard> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  //endCall() {}

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Container(
      child: widget.remoteRenderer.textureId == null
          ? Container()
          : FittedBox(
              fit: BoxFit.cover,
              child: Container(
                height: size.width * .55,
                width: size.width * .35,
                child: RTCVideoView(
                  widget.remoteRenderer,
                  mirror: true,
                  objectFit:
                  RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              ),
            ),
    );
  }
}
