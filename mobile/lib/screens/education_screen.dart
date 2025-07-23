import 'package:flutter/material.dart';
import '../models/education.dart';
import '../services/education_service.dart';
import '../widgets/education/tutorial_card.dart';
import '../widgets/education/glossary_search.dart';
import '../widgets/education/comparison_card.dart';
import '../widgets/education/learning_progress_widget.dart';

class EducationScreen extends StatefulWidget {
  const EducationScreen({Key? key}) : super(key: key);

  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final EducationService _educationService = EducationService();
  
  // State management
  bool _isLoading = true;
  String? _error;
  
  // Data
  List<Tutorial> _featuredTutorials = [];
  List<Tutorial> _recommendedTutorials = [];
  List<Comparison> _recentComparisons = [];
  UserProgress? _userProgress;
  LearningRecommendations? _recommendations;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _educationService.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load featured tutorials, recommendations, and user progress in parallel
      final futures = await Future.wait([
        _educationService.getTutorials(featured: true, limit: 5),
        _educationService.getLearningRecommendations(),
        _educationService.getComparisons(limit: 3),
        _educationService.getUserProgress(),
      ]);

      setState(() {
        _featuredTutorials = (futures[0] as TutorialResponse).tutorials;
        _recommendations = futures[1] as LearningRecommendations;
        _recommendedTutorials = _recommendations!.recommendedTutorials;
        _recentComparisons = (futures[2] as ComparisonResponse).comparisons;
        _userProgress = futures[3] as UserProgress;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    await _loadInitialData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learn Photography'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.home), text: 'Home'),
            Tab(icon: Icon(Icons.school), text: 'Tutorials'),
            Tab(icon: Icon(Icons.compare), text: 'Examples'),
            Tab(icon: Icon(Icons.book), text: 'Glossary'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHomeTab(),
          _buildTutorialsTab(),
          _buildExamplesTab(),
          _buildGlossaryTab(),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome & Progress Section
            if (_userProgress != null) ...[
              LearningProgressWidget(userProgress: _userProgress!),
              const SizedBox(height: 24),
            ],

            // Recommendations Section
            if (_recommendations != null) ...[
              _buildSectionHeader('Recommended for You', _recommendations!.reason),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _recommendedTutorials.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.only(
                        right: index < _recommendedTutorials.length - 1 ? 12 : 0,
                      ),
                      child: SizedBox(
                        width: 280,
                        child: TutorialCard(
                          tutorial: _recommendedTutorials[index],
                          onTap: () => _openTutorial(_recommendedTutorials[index]),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Featured Tutorials Section
            _buildSectionHeader('Featured Tutorials', 'Popular with beginners'),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _featuredTutorials.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index < _featuredTutorials.length - 1 ? 12 : 0,
                    ),
                    child: SizedBox(
                      width: 280,
                      child: TutorialCard(
                        tutorial: _featuredTutorials[index],
                        onTap: () => _openTutorial(_featuredTutorials[index]),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Recent Comparisons Section
            _buildSectionHeader('Before & After Examples', 'See the difference'),
            const SizedBox(height: 12),
            Column(
              children: _recentComparisons.map((comparison) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ComparisonCard(
                    comparison: comparison,
                    onTap: () => _openComparison(comparison),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTutorialsTab() {
    return TutorialsTabView(educationService: _educationService);
  }

  Widget _buildExamplesTab() {
    return ExamplesTabView(educationService: _educationService);
  }

  Widget _buildGlossaryTab() {
    return GlossarySearch(educationService: _educationService);
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  void _openTutorial(Tutorial tutorial) {
    Navigator.pushNamed(
      context,
      '/tutorial-detail',
      arguments: tutorial,
    );
  }

  void _openComparison(Comparison comparison) {
    Navigator.pushNamed(
      context,
      '/comparison-detail',
      arguments: comparison,
    );
  }
}

// Tutorials Tab View
class TutorialsTabView extends StatefulWidget {
  final EducationService educationService;

  const TutorialsTabView({Key? key, required this.educationService}) : super(key: key);

  @override
  State<TutorialsTabView> createState() => _TutorialsTabViewState();
}

class _TutorialsTabViewState extends State<TutorialsTabView> {
  List<Tutorial> _tutorials = [];
  bool _isLoading = false;
  String? _selectedCategory;
  String? _selectedDifficulty;

  final List<String> _categories = [
    'basics',
    'exposure',
    'composition',
    'scene_types',
    'advanced_techniques'
  ];

  final List<String> _difficulties = ['beginner', 'intermediate', 'advanced'];

  @override
  void initState() {
    super.initState();
    _loadTutorials();
  }

  Future<void> _loadTutorials() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await widget.educationService.getTutorials(
        category: _selectedCategory,
        difficulty: _selectedDifficulty,
        limit: 20,
      );
      
      setState(() {
        _tutorials = response.tutorials;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading tutorials: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filters
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Categories')),
                    ..._categories.map((category) => DropdownMenuItem(
                      value: category,
                      child: Text(category.replaceAll('_', ' ').toUpperCase()),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedCategory = value);
                    _loadTutorials();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedDifficulty,
                  decoration: const InputDecoration(
                    labelText: 'Difficulty',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Levels')),
                    ..._difficulties.map((difficulty) => DropdownMenuItem(
                      value: difficulty,
                      child: Text(difficulty.toUpperCase()),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedDifficulty = value);
                    _loadTutorials();
                  },
                ),
              ),
            ],
          ),
        ),
        
        // Tutorials List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _tutorials.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TutorialCard(
                        tutorial: _tutorials[index],
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/tutorial-detail',
                          arguments: _tutorials[index],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// Examples Tab View
class ExamplesTabView extends StatefulWidget {
  final EducationService educationService;

  const ExamplesTabView({Key? key, required this.educationService}) : super(key: key);

  @override
  State<ExamplesTabView> createState() => _ExamplesTabViewState();
}

class _ExamplesTabViewState extends State<ExamplesTabView> {
  List<Comparison> _comparisons = [];
  bool _isLoading = false;
  String? _selectedCategory;

  final List<String> _categories = [
    'exposure',
    'aperture',
    'shutter_speed',
    'iso',
    'white_balance',
    'focus',
    'composition'
  ];

  @override
  void initState() {
    super.initState();
    _loadComparisons();
  }

  Future<void> _loadComparisons() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await widget.educationService.getComparisons(
        category: _selectedCategory,
        limit: 20,
      );
      
      setState(() {
        _comparisons = response.comparisons;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading comparisons: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Category Filter
        Container(
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Categories')),
              ..._categories.map((category) => DropdownMenuItem(
                value: category,
                child: Text(category.replaceAll('_', ' ').toUpperCase()),
              )),
            ],
            onChanged: (value) {
              setState(() => _selectedCategory = value);
              _loadComparisons();
            },
          ),
        ),
        
        // Comparisons List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _comparisons.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ComparisonCard(
                        comparison: _comparisons[index],
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/comparison-detail',
                          arguments: _comparisons[index],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}