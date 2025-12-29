// simple game model
class Games {
  final String id;
  final String team_name;
  final String start_time;
  final String status;
  //placeholder for future use
  final String probability;
  
  Games({
    required this.id,
    required this.team_name,
    required this.start_time,
    required this.status,
    required this.probability,
  });
}