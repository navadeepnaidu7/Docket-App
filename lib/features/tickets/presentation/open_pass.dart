import 'package:flutter/material.dart';
import '../../../core/motion/studio_page_route.dart';
import '../domain/pass_catalog.dart';
import 'bus/bus_pass_detail_screen.dart';
import 'movie_pass_detail_screen.dart';
import 'ticket_detail_screen.dart';

Future<void> openPass(BuildContext context, WalletPassItem item) =>
    Navigator.of(context).push<void>(
      studioPageRoute<void>(
        builder: (_) => switch (item) {
          TrainPassItem(:final ticket) => TicketDetailScreen(ticket: ticket),
          MoviePassItem(:final pass) => MoviePassDetailScreen(pass: pass),
          BusPassItem(:final pass) => BusPassDetailScreen(pass: pass),
        },
      ),
    );
