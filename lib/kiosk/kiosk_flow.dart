/// Data carried through one kiosk transaction, screen to screen.
class KioskFlow {
  /// Normalised control number the resident typed (e.g. "PC-4EEE-M4").
  String controlNo = '';

  /// Second factor entered on the confirm step.
  String surname = '';

  /// From the verify response — shown back to the resident for confirmation.
  String fullName = '';
  String purok = '';

  /// Chosen documents: each entry is {documentType, purpose}.
  final List<DocSelection> selections = [];

  void reset() {
    controlNo = '';
    surname = '';
    fullName = '';
    purok = '';
    selections.clear();
  }

  List<Map<String, String>> toItems() => selections
      .map((s) => {
            'documentType': s.documentType,
            'purpose': s.purpose,
          })
      .toList();
}

class DocSelection {
  final String documentType;
  String purpose;
  DocSelection(this.documentType, this.purpose);
}
