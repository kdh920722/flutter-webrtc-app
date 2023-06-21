import 'dart:developer';

import 'package:flutter/material.dart';
import 'call_screen.dart';
import '../services/signalling.service.dart';

class JoinScreen extends StatefulWidget {
  final String selfCallerId;

  const JoinScreen({super.key, required this.selfCallerId});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  dynamic incomingSDPOffer;
  final remoteCallerIdTextEditingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // listen for incoming video call
    SignallingService.instance.socket!.on("newCall", (data) {
      if (mounted) {
        // set SDP Offer of incoming call
        setState(() => incomingSDPOffer = data);
      }
    });
  }

  // join Call
  _joinCall({
    required String callerId,
    required String calleeId,
    dynamic offer,
  }) {
    setState(() => incomingSDPOffer = null);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          callerId: callerId,
          calleeId: calleeId,
          offer: offer,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        centerTitle: true,
        title: const Text("META CALL"),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextField(
                      style: const TextStyle(color: Color(0xffbb86fc)),
                      controller: TextEditingController(
                        text: widget.selfCallerId,
                      ),
                      readOnly: true,
                      textAlign: TextAlign.center,
                      enableInteractiveSelection: false,
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xffbb86fc)),
                          borderRadius: BorderRadius.circular(10.0),
                          ),
                        labelText: "내 ID",
                        labelStyle: const TextStyle(color: Color(0xffbb86fc)),
                        border: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xffbb86fc)),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 150),
                    TextField(
                      style: const TextStyle(color: Colors.grey),
                      controller: remoteCallerIdTextEditingController,
                      textAlign: TextAlign.center,
                      cursorColor: Colors.grey,
                      decoration: InputDecoration(
                        hintText: "상대방 ID",
                        hintStyle: const TextStyle(color: Colors.grey),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        fixedSize: Size(MediaQuery.of(context).size.width * 0.8,40),
                        shape: RoundedRectangleBorder( //to set border radius to button
                            borderRadius: BorderRadius.circular(20)
                        ),
                        backgroundColor: const Color(0xffbb86fc)
                      ),
                      child: const Text(
                        "영상통화",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                      onPressed: () {
                        if(remoteCallerIdTextEditingController.text.trim() != ""){
                          _joinCall(
                            callerId: widget.selfCallerId,
                            calleeId: remoteCallerIdTextEditingController.text,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (incomingSDPOffer != null)
              Positioned(
                child: ListTile(
                  title: Text(
                    "${incomingSDPOffer["callerId"]}님이 영상통화를 요청합니다.",
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.call_end),
                        color: Colors.redAccent,
                        onPressed: () {
                          setState(() => incomingSDPOffer = null);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.call),
                        color: Colors.greenAccent,
                        onPressed: () {
                          _joinCall(
                            callerId: incomingSDPOffer["callerId"]!,
                            calleeId: widget.selfCallerId,
                            offer: incomingSDPOffer["sdpOffer"],
                          );
                        },
                      )
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
