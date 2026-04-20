/// Registers framework observers that broadcast structured JSON events to VM
/// service clients via [postEvent].
///
/// Call once from [Agent.initialize]. Safe to call multiple times.
///
/// New telemetry events go here; register any observer hooks and document in
/// `docs/service_extensions.md`.
void initTelemetry() {}
