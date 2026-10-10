import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/appointment_model.dart';
import '../../../utils/appointment_v2_utils.dart';

/// 30-Minute Time Slot Filter modal matching React TimeSlotFilterModal
class TimeSlotFilterModal extends StatefulWidget {
  final List<BusinessSlot> slots;
  final List<AppointmentModel> appointments;
  final String initialFilter; // 'all', 'available', 'booked'
  final ValueChanged<BusinessSlot> onSelectSlot;
  final VoidCallback onClose;

  const TimeSlotFilterModal({
    super.key,
    required this.slots,
    required this.appointments,
    this.initialFilter = 'all',
    required this.onSelectSlot,
    required this.onClose,
  });

  @override
  State<TimeSlotFilterModal> createState() => _TimeSlotFilterModalState();
}

class _TimeSlotFilterModalState extends State<TimeSlotFilterModal> {
  late String _filterStatus; // 'all', 'available', 'booked'

  @override
  void initState() {
    super.initState();
    _filterStatus = widget.initialFilter;
  }

  Map<String, List<AppointmentModel>> _buildSlotMap() {
    final map = <String, List<AppointmentModel>>{};
    for (final slot in widget.slots) {
      final matches = widget.appointments.where((a) {
        final aStart = timeToMinutes(a.startTime);
        final aEnd = timeToMinutes(a.endTime);
        return slot.startM < aEnd && slot.endM > aStart;
      }).toList();
      map[slot.start24] = matches;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final slotMap = _buildSlotMap();

    final filtered = widget.slots.where((slot) {
      final appts = slotMap[slot.start24] ?? [];
      final isBooked = appts.isNotEmpty;
      if (_filterStatus == 'available') return !isBooked;
      if (_filterStatus == 'booked') return isBooked;
      return true;
    }).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: Container(
          width: 540,
          constraints: const BoxConstraints(maxHeight: 640),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x330F172A),
                blurRadius: 28,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFAFBFC),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.filter_alt_outlined, size: 18, color: Color(0xFF2563EB)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '30-Minute Time Slot Overview',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),

              // 2. Filter Status Tabs
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildFilterTab(
                          label: 'All Slots (${widget.slots.length})',
                          status: 'all',
                        ),
                      ),
                      Expanded(
                        child: _buildFilterTab(
                          label: 'Available Only',
                          status: 'available',
                        ),
                      ),
                      Expanded(
                        child: _buildFilterTab(
                          label: 'Booked Only',
                          status: 'booked',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Filtered Slots Grid
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: filtered.map((slot) {
                      final appts = slotMap[slot.start24] ?? [];
                      final isBooked = appts.isNotEmpty;
                      final statusMeta = isBooked ? getStatusMeta(appts.first.status) : null;

                      return InkWell(
                        onTap: () {
                          widget.onSelectSlot(slot);
                          widget.onClose();
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 154,
                          decoration: BoxDecoration(
                            color: isBooked ? statusMeta!.bg : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isBooked ? statusMeta!.border : const Color(0xFFE2E8F0),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                slot.label,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isBooked ? statusMeta!.color : const Color(0xFF16A34A),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      isBooked ? statusMeta!.label : 'Available',
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: isBooked ? statusMeta!.color : const Color(0xFF16A34A),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // 4. Footer
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFAFBFC),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: widget.onClose,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'Close',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTab({required String label, required String status}) {
    final isSelected = (_filterStatus == status);

    return InkWell(
      onTap: () => setState(() => _filterStatus = status),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? const [BoxShadow(color: Color(0x0A000000), blurRadius: 3, offset: Offset(0, 1))]
              : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
