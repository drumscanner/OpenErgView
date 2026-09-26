import 'dart:async';

import 'package:c2bluetooth/c2bluetooth.dart';
import 'package:flutter/material.dart';
import 'package:openergview/constants.dart';
import 'package:openergview/settings_screen.dart';
import 'package:provider/provider.dart';

import 'src/average_power_tracker.dart';
import 'src/components/data_tile.dart';
import 'src/tabviews/erg_grid_view.dart';
import 'src/tabviews/erg_staggered_view.dart';
import 'src/ergometerstore.dart';
import 'src/recording/recording_controller.dart';
import 'src/recording/recording_settings.dart';
import 'utils.dart';

class MainScreen extends StatefulWidget {
  MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

///depends on [ErgometerStore]
class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  ErgometerConnectionState lastConnectionState =
      ErgometerConnectionState.disconnected;

  Stream<ErgometerConnectionState>? _ergConnectionStatusStream;

  StreamSubscription<ErgometerConnectionState>? _ergConnectionStatus;

  late ErgometerStore? ergstore;

  // Tracks which erg we've already connected to/started recording for, so that
  // didChangeDependencies re-running (e.g. on unrelated Provider updates) doesn't
  // reconnect or start a duplicate recording for the same erg.
  Ergometer? _connectedErg;

  RecordingController? _recordingController;

  AveragePowerTracker? _averagePowerTracker;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    ergstore = Provider.of<ErgometerStore>(context);
    final erg = ergstore?.erg;

    if (erg != null && erg != _connectedErg) {
      _connectedErg = erg;

      _ergConnectionStatusStream = erg.monitorConnectionState().asBroadcastStream(
        onCancel: (controller) {
          print('Stream paused');
          controller.pause();
        },
        onListen: (controller) async {
          if (controller.isPaused) {
            print('Stream resumed');
            controller.resume();
          }
        },
      );

      _ergConnectionStatus = _ergConnectionStatusStream
          ?.listen((ErgometerConnectionState connectionState) {
        // Without setState, widgets reading lastConnectionState directly (like the "Start
        // workout" button's enabled state) wouldn't rebuild until something unrelated
        // happened to trigger one - e.g. changing pages.
        if (mounted) {
          setState(() {
            lastConnectionState = connectionState;
          });
        }
      });

      _recordingController?.dispose();
      _recordingController = RecordingController(
        erg: erg,
        settings: Provider.of<RecordingSettings>(context, listen: false),
      );

      _averagePowerTracker?.dispose();
      _averagePowerTracker = AveragePowerTracker(erg);

      erg.connectAndDiscover();
    }
  }

  Future<void> _disconnect() async {
    final erg = _connectedErg;
    if (erg == null) {
      return;
    }

    _recordingController?.dispose();
    _recordingController = null;
    await _averagePowerTracker?.dispose();
    _averagePowerTracker = null;
    await _ergConnectionStatus?.cancel();
    _ergConnectionStatus = null;
    _connectedErg = null;

    setState(() {
      lastConnectionState = ErgometerConnectionState.disconnected;
    });

    await erg.disconnectOrCancel();
    ergstore?.erg = null;
  }

  /// Sends the CSAFE start-workout sequence. Returns whether it succeeded, so the caller can
  /// decide whether it's safe to navigate to the data page.
  Future<bool> _startWorkout() async {
    final erg = ergstore?.erg;
    if (erg == null) {
      return false;
    }
    try {
      await erg.startWorkoutSession();
      _averagePowerTracker?.reset();
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to start workout: $e')));
      }
      return false;
    }
  }

  List<Widget> _buildPageIndicator(length, selectedIndex) {
    List<Widget> list = [];
    for (int i = 0; i < length; i++) {
      // list.add(i == selectedIndex ? TabIndicator(true) : TabIndicator(false));
      list.add(i == selectedIndex
          ? const TabPageSelectorIndicator(
              backgroundColor: Colors.white,
              borderColor: Colors.white,
              size: 12,
              borderStyle: BorderStyle.solid,
            )
          : const TabPageSelectorIndicator(
              backgroundColor: Colors.grey,
              borderColor: Colors.grey,
              size: 12,
              borderStyle: BorderStyle.solid,
            ));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final PageController pageController = PageController(initialPage: 0);

    final List<Widget> pages = <Widget>[
      Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start workout'),
          onPressed: (ergstore?.erg != null &&
                  lastConnectionState == ErgometerConnectionState.connected)
              ? () async {
                  final started = await _startWorkout();
                  if (started) {
                    pageController.animateToPage(1,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.ease);
                  }
                }
              : null,
        ),
      ),
      ErgStaggeredView(
          ergstore: ergstore,
          averagePaceStream: _averagePowerTracker?.averagePace,
          children: [
        DataTile(
            title: "distance",
            defaultValue: 1,
            stream: getDoubleDataStream(ergstore, "general.distance")),
        DataTile(
            title: "Drive Length",
            defaultValue: 1.27,
            unit: "m",
            decimals: 2,
            stream: getDoubleDataStream(ergstore, "stroke.drive_length"))
      ]),
      ErgGridView(
        children: [
          DataTile(
              title: "distance",
              defaultValue: 1,
              stream: getDoubleDataStream(ergstore, "general.distance")),
          DataTile(
              title: "Drive Length",
              defaultValue: 1.27,
              unit: "m",
              decimals: 2,
              stream:
                  getDoubleDataStream(ergstore, "stroke.drive_length")),
          DataTile(
              title: "Average Force",
              defaultValue: 264,
              unit: "lb",
              stream: getDoubleDataStream(
                  ergstore, "stroke.drive_force.average")),
          DataTile(title: "Drag Factor", defaultValue: 218),
          //TODO: drive length over drive time
          DataTile(
            title: "Drive Speed",
            defaultValue: 12.10,
            unit: "m/s",
            decimals: 2,
          ),
          DataTile(
              title: "Peak Force",
              defaultValue: 341,
              unit: "lb",
              stream: getDoubleDataStream(
                  ergstore, "stroke.drive_force.max"))
        ],
      ),
      ErgGridView(
        children: [
          DataTile(title: "test", defaultValue: 1),
          DataTile(title: "test", defaultValue: 2),
          DataTile(title: "test", defaultValue: 3),
          DataTile(title: "test", defaultValue: 4),
          DataTile(title: "test", defaultValue: 5),
          DataTile(title: "test", defaultValue: 6)
        ],
      )
    ];

    return SafeArea(
        child: Scaffold(
            body: PageView(
              /// [PageView.scrollDirection] defaults to [Axis.horizontal].
              /// Use [Axis.vertical] to scroll vertically.
              controller: pageController,
              onPageChanged: (newIndex) {
                setState(() {
                  _currentIndex = newIndex;
                });
              },
              children: pages,
            ),
            bottomNavigationBar: Container(
              height: kBottomNavigationBarHeight,
              decoration: BoxDecoration(
                gradient: getDarkGradient(context),
                color: Colors.indigo,
              ),
              child: BottomAppBar(
                color: Colors.transparent,
                child: IconTheme(
                    data: IconThemeData(
                        color: Theme.of(context).colorScheme.onPrimary),
                    child: Row(
                      children: <Widget>[
                        StreamBuilder<ErgometerConnectionState>(
                            stream: _ergConnectionStatusStream,
                            initialData: lastConnectionState,
                            builder: (BuildContext context,
                                AsyncSnapshot<ErgometerConnectionState>
                                    snapshot) {
                              if (snapshot.hasError) {
                                return const Text(
                                  "Error",
                                  style: TextStyle(
                                      fontSize: 16.0, color: Colors.red),
                                );
                              } else {
                                switch (snapshot.connectionState) {
                                  case ConnectionState.none:
                                    return const Text(
                                      "Please Connect PM",
                                      style: TextStyle(
                                          fontSize: 16.0, color: Colors.white),
                                    );
                                  case ConnectionState.waiting:
                                    return const CircularProgressIndicator();
                                  case ConnectionState.active:
                                  case ConnectionState.done:
                                    switch (snapshot.data) {
                                      case ErgometerConnectionState.connecting:
                                        return const Text(
                                          "Connecting...",
                                          style: TextStyle(
                                              fontSize: 16.0,
                                              color: Colors.yellow),
                                        );
                                      case ErgometerConnectionState.connected:
                                        return const Text(
                                          "Connected to erg",
                                          style: TextStyle(
                                              fontSize: 16.0,
                                              color: Colors.green),
                                        );
                                      case ErgometerConnectionState
                                            .disconnected:
                                        return const Text(
                                          "Disconnected",
                                          style: TextStyle(
                                              fontSize: 16.0,
                                              color: Colors.red),
                                        );
                                      default:
                                        return const Text(
                                          "Unknown",
                                          style: TextStyle(
                                              fontSize: 16.0,
                                              color: Colors.white),
                                        );
                                    }
                                }
                              }
                            }),
                        if (_connectedErg != null)
                          IconButton(
                            tooltip: 'Disconnect',
                            icon: const Icon(Icons.link_off),
                            onPressed: _disconnect,
                          ),
                        const Spacer(),
                        if (isPointerDevice(context))
                          IconButton(
                            tooltip: 'Previous',
                            icon: const Icon(Icons.arrow_back),
                            disabledColor: Colors.grey,
                            onPressed: _currentIndex != 0
                                ? () => setState(() {
                                      pageController.animateToPage(
                                          _currentIndex - 1,
                                          duration: Duration(milliseconds: 500),
                                          curve: Curves.ease);
                                    })
                                : null,
                          ),
                        Row(
                            children: _buildPageIndicator(
                                pages.length, _currentIndex)),
                        if (isPointerDevice(context))
                          IconButton(
                            tooltip: 'Next',
                            icon: const Icon(Icons.arrow_forward),
                            disabledColor: Colors.grey,
                            onPressed: _currentIndex != pages.length - 1
                                ? () => setState(() {
                                      pageController.animateToPage(
                                          _currentIndex + 1,
                                          duration: Duration(milliseconds: 500),
                                          curve: Curves.ease);
                                    })
                                : null,
                          ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Settings',
                          padding: const EdgeInsets.all(0),
                          icon: const Icon(Icons.settings),
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) => SettingsScreen()));
                          },
                        ),
                      ],
                    )),
              ),
            )));
  }

  @override
  void dispose() {
    _ergConnectionStatus?.cancel();
    _recordingController?.dispose();
    _averagePowerTracker?.dispose();
    super.dispose();
  }
}
