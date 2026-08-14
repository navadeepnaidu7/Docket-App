import 'package:flutter/material.dart';

import '../../../../shared/widgets/apple_sheet.dart';
import '../../../../shared/widgets/entry/entry_method_card.dart';
import '../../domain/pass_ingest.dart';

class AddPassSheet extends StatelessWidget {
  const AddPassSheet({super.key, required this.onSelect});

  final ValueChanged<PassInputCategory> onSelect;

  @override
  Widget build(BuildContext context) {
    return AppleSheet(
      title: 'Add a pass',
      subtitle: 'Train, bus, or movie ticket',
      showDragHandle: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          EntryMethodCard(
            hero: true,
            icon: Icons.train_rounded,
            title: 'Train',
            subtitle: 'PNR, photo, or PDF',
            onTap: () => onSelect(PassInputCategory.train),
          ),
          const SizedBox(height: 10),
          EntryMethodCard(
            icon: Icons.directions_bus_rounded,
            title: 'Bus',
            subtitle: 'Photo or PDF of the ticket',
            onTap: () => onSelect(PassInputCategory.bus),
          ),
          const SizedBox(height: 10),
          EntryMethodCard(
            icon: Icons.confirmation_number_rounded,
            title: 'Movie',
            subtitle: 'Screenshot or PDF of the booking',
            onTap: () => onSelect(PassInputCategory.movie),
          ),
        ],
      ),
    );
  }
}

class AddPassMethodSheet extends StatelessWidget {
  const AddPassMethodSheet({
    super.key,
    required this.category,
    required this.onSelect,
  });

  final PassInputCategory category;
  final ValueChanged<PassInputSource> onSelect;

  @override
  Widget build(BuildContext context) {
    final bool train = category == PassInputCategory.train;
    return AppleSheet(
      title: switch (category) {
        PassInputCategory.train => 'Add a train pass',
        PassInputCategory.bus => 'Add a bus pass',
        PassInputCategory.movie => 'Add a movie pass',
      },
      subtitle: train
          ? 'IRCTC PNR, or a photo / PDF of the ticket'
          : 'Photo or PDF — we read the details on the server',
      showDragHandle: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (train) ...<Widget>[
            EntryMethodCard(
              hero: true,
              icon: Icons.pin_rounded,
              title: 'Enter PNR',
              subtitle: '10-digit IRCTC booking number',
              onTap: () => onSelect(PassInputSource.pnr),
            ),
            const SizedBox(height: 10),
          ],
          EntryMethodCard(
            hero: !train,
            icon: Icons.photo_camera_rounded,
            title: 'Take or choose a photo',
            subtitle: 'Camera or library',
            onTap: () => onSelect(PassInputSource.photo),
          ),
          const SizedBox(height: 10),
          EntryMethodCard(
            icon: Icons.picture_as_pdf_rounded,
            title: 'Upload a PDF',
            subtitle: train
                ? 'IRCTC ticket or booking confirmation'
                : 'Ticket or booking confirmation',
            onTap: () => onSelect(PassInputSource.pdf),
          ),
        ],
      ),
    );
  }
}
