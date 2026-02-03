import 'dart:async';
import 'dart:math';
import '../../features/patients/data/models/tremor_analysis.dart';

/// Service for generating realistic simulated tremor data
/// Useful for demonstration and testing without actual hardware
class TremorSimulationService {
  static final TremorSimulationService _instance = TremorSimulationService._internal();
  factory TremorSimulationService() => _instance;
  TremorSimulationService._internal();

  final Random _random = Random();
  Timer? _simulationTimer;
  final List<TremorDataPoint> _simulatedData = [];
  
  // Simulation parameters
  double _baselineScore = 25.0;  // Normal baseline tremor score
  double _currentTrend = 0.0;    // Current trend direction
  bool _inEpisode = false;       // Whether in a parkinsonian episode
  int _episodeDuration = 0;      // Remaining duration of current episode
  
  // Stream controller for real-time updates
  final StreamController<List<TremorDataPoint>> _dataStreamController = 
      StreamController<List<TremorDataPoint>>.broadcast();
  
  Stream<List<TremorDataPoint>> get dataStream => _dataStreamController.stream;
  List<TremorDataPoint> get currentData => List.unmodifiable(_simulatedData);
  bool get isRunning => _simulationTimer != null && _simulationTimer!.isActive;

  /// Start generating simulated tremor data
  /// [intervalMs] - Time between data points in milliseconds
  void startSimulation({int intervalMs = 1000}) {
    stopSimulation();
    _simulatedData.clear();
    _resetSimulationState();
    
    // Generate initial historical data (last 30 seconds)
    final now = DateTime.now();
    for (int i = 30; i > 0; i--) {
      final timestamp = now.subtract(Duration(seconds: i));
      _simulatedData.add(_generateDataPoint(timestamp));
    }
    _dataStreamController.add(List.from(_simulatedData));
    
    // Start real-time simulation
    _simulationTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) => _generateNewPoint(),
    );
  }

  /// Stop the simulation
  void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  /// Clear all simulated data
  void clearData() {
    stopSimulation();
    _simulatedData.clear();
    _dataStreamController.add([]);
  }

  void _resetSimulationState() {
    _baselineScore = 20 + _random.nextDouble() * 15;  // 20-35 baseline
    _currentTrend = 0.0;
    _inEpisode = false;
    _episodeDuration = 0;
  }

  void _generateNewPoint() {
    final point = _generateDataPoint(DateTime.now());
    _simulatedData.add(point);
    
    // Keep only last 120 points (2 minutes of data at 1Hz)
    if (_simulatedData.length > 120) {
      _simulatedData.removeAt(0);
    }
    
    _dataStreamController.add(List.from(_simulatedData));
  }

  TremorDataPoint _generateDataPoint(DateTime timestamp) {
    double tremorScore;
    bool isParkinsonian = false;
    
    // Check for random episode start (3% chance per second when not in episode)
    if (!_inEpisode && _random.nextDouble() < 0.03) {
      _inEpisode = true;
      _episodeDuration = 5 + _random.nextInt(10);  // 5-15 seconds
    }
    
    if (_inEpisode) {
      // Parkinsonian episode - elevated tremor with 4-6 Hz frequency pattern
      final episodeIntensity = 0.5 + _random.nextDouble() * 0.5;  // 0.5-1.0
      tremorScore = 55 + episodeIntensity * 35 + _random.nextDouble() * 10;  // 55-100
      
      // Add characteristic oscillation pattern
      final oscillation = sin(timestamp.millisecondsSinceEpoch / 200.0) * 5;
      tremorScore += oscillation;
      
      isParkinsonian = tremorScore > 50;
      
      _episodeDuration--;
      if (_episodeDuration <= 0) {
        _inEpisode = false;
      }
    } else {
      // Normal state with natural variation
      
      // Update trend (random walk)
      _currentTrend += (_random.nextDouble() - 0.5) * 2;
      _currentTrend = _currentTrend.clamp(-5.0, 5.0);
      
      // Calculate score with baseline, trend, and noise
      final noise = (_random.nextDouble() - 0.5) * 10;  // ±5
      tremorScore = _baselineScore + _currentTrend + noise;
      
      // Add subtle natural tremor oscillation
      final naturalOscillation = sin(timestamp.millisecondsSinceEpoch / 500.0) * 3;
      tremorScore += naturalOscillation;
      
      // Occasional small spikes (physiological tremor)
      if (_random.nextDouble() < 0.05) {
        tremorScore += 10 + _random.nextDouble() * 15;  // +10-25 spike
      }
    }
    
    // Clamp to valid range
    tremorScore = tremorScore.clamp(0.0, 100.0);
    
    // Mark as parkinsonian if above threshold
    if (tremorScore > 50) {
      isParkinsonian = true;
    }
    
    return TremorDataPoint(
      timestamp: timestamp,
      tremorScore: tremorScore,
      isParkinsonian: isParkinsonian,
    );
  }

  /// Generate a burst of parkinsonian tremor for demonstration
  void triggerParkinsonianEpisode() {
    _inEpisode = true;
    _episodeDuration = 8 + _random.nextInt(7);  // 8-15 seconds
  }

  /// Get simulated statistics matching the API format
  Map<String, dynamic> getSimulatedStatistics() {
    if (_simulatedData.isEmpty) {
      return {'statistics': null};
    }

    final scores = _simulatedData.map((d) => d.tremorScore).toList();
    final avgScore = scores.reduce((a, b) => a + b) / scores.length;
    final maxScore = scores.reduce(max);
    final minScore = scores.reduce(min);
    final parkinsonianCount = _simulatedData.where((d) => d.isParkinsonian).length;
    
    // Simulate dominant frequency (4-6 Hz for parkinsonian, 8-12 Hz for physiological)
    final avgFreq = parkinsonianCount > scores.length * 0.3 
        ? 4.5 + _random.nextDouble() * 1.5  // 4.5-6 Hz
        : 8.0 + _random.nextDouble() * 4.0; // 8-12 Hz

    return {
      'statistics': {
        'tremor_scores': {
          'average': avgScore,
          'max': maxScore,
          'min': minScore,
          'std_dev': _calculateStdDev(scores, avgScore),
        },
        'total_readings': scores.length,
        'parkinsonian_episodes': parkinsonianCount,
        'frequency_analysis': {
          'avg_dominant_freq': avgFreq,
        },
      },
      'time_range': {
        'start': _simulatedData.first.timestamp.toIso8601String(),
        'end': _simulatedData.last.timestamp.toIso8601String(),
      },
    };
  }

  double _calculateStdDev(List<double> values, double mean) {
    if (values.length < 2) return 0.0;
    final sumSquaredDiff = values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b);
    return sqrt(sumSquaredDiff / (values.length - 1));
  }

  void dispose() {
    stopSimulation();
    _dataStreamController.close();
  }
}
