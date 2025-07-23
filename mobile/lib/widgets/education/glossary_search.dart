import 'package:flutter/material.dart';
import '../../models/education.dart';
import '../../services/education_service.dart';

class GlossarySearch extends StatefulWidget {
  final EducationService educationService;

  const GlossarySearch({
    Key? key,
    required this.educationService,
  }) : super(key: key);

  @override
  State<GlossarySearch> createState() => _GlossarySearchState();
}

class _GlossarySearchState extends State<GlossarySearch> {
  final TextEditingController _searchController = TextEditingController();
  List<GlossaryTerm> _terms = [];
  List<GlossaryTerm> _filteredTerms = [];
  bool _isLoading = false;
  String? _selectedCategory;

  final List<String> _categories = [
    'exposure',
    'focus',
    'composition',
    'camera_controls',
    'lighting',
    'post_processing'
  ];

  @override
  void initState() {
    super.initState();
    _loadGlossary();
    _searchController.addListener(_filterTerms);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGlossary() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await widget.educationService.getGlossary(
        category: _selectedCategory,
        limit: 100,
      );
      
      setState(() {
        _terms = response.glossary;
        _filteredTerms = _terms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading glossary: $e')),
      );
    }
  }

  void _filterTerms() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTerms = _terms.where((term) {
        return term.term.toLowerCase().contains(query) ||
               term.plainLanguageExplanation.toLowerCase().contains(query) ||
               term.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search and Filter Section
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Search Bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search photography terms...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Category Filter
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Categories')),
                  ..._categories.map((category) => DropdownMenuItem(
                    value: category,
                    child: Text(_formatCategoryName(category)),
                  )),
                ],
                onChanged: (value) {
                  setState(() => _selectedCategory = value);
                  _loadGlossary();
                },
              ),
            ],
          ),
        ),
        
        // Results Section
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredTerms.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: _filteredTerms.length,
                      itemBuilder: (context, index) {
                        return GlossaryTermCard(
                          term: _filteredTerms[index],
                          onTap: () => _showTermDetail(_filteredTerms[index]),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty
                ? 'No terms found for "${_searchController.text}"'
                : 'No terms available',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filter',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  void _showTermDetail(GlossaryTerm term) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) {
          return GlossaryTermDetail(
            term: term,
            scrollController: scrollController,
          );
        },
      ),
    );
  }

  String _formatCategoryName(String category) {
    return category
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

class GlossaryTermCard extends StatelessWidget {
  final GlossaryTerm term;
  final VoidCallback onTap;

  const GlossaryTermCard({
    Key? key,
    required this.term,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: Text(
          term.term,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              term.plainLanguageExplanation,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildCategoryChip(context),
                const SizedBox(width: 8),
                _buildDifficultyChip(context),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
        isThreeLine: true,
      ),
    );
  }

  Widget _buildCategoryChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Text(
        term.category.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade700,
        ),
      ),
    );
  }

  Widget _buildDifficultyChip(BuildContext context) {
    Color chipColor;
    switch (term.difficulty.toLowerCase()) {
      case 'beginner':
        chipColor = Colors.green;
        break;
      case 'intermediate':
        chipColor = Colors.orange;
        break;
      case 'advanced':
        chipColor = Colors.red;
        break;
      default:
        chipColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: Text(
        term.difficulty.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: chipColor.shade700,
        ),
      ),
    );
  }
}

class GlossaryTermDetail extends StatelessWidget {
  final GlossaryTerm term;
  final ScrollController scrollController;

  const GlossaryTermDetail({
    Key? key,
    required this.term,
    required this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ListView(
        controller: scrollController,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Term Title
          Text(
            term.term,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Categories and Tags
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildChip(
                term.category.replaceAll('_', ' ').toUpperCase(),
                Colors.blue,
              ),
              _buildChip(
                term.difficulty.toUpperCase(),
                _getDifficultyColor(term.difficulty),
              ),
              ...term.tags.map((tag) => _buildChip(
                tag.toUpperCase(),
                Colors.grey,
              )),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Plain Language Explanation
          _buildSection(
            context,
            'Simple Explanation',
            term.plainLanguageExplanation,
            Icons.lightbulb_outline,
          ),
          
          const SizedBox(height: 16),
          
          // Technical Definition
          _buildSection(
            context,
            'Technical Definition',
            term.technicalDefinition,
            Icons.science,
          ),
          
          // Examples
          if (term.examples.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Examples',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...term.examples.map((example) => _buildExample(context, example)),
          ],
          
          // Related Terms
          if (term.relatedTerms.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Related Terms',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: term.relatedTerms.map((relatedTerm) {
                return ActionChip(
                  label: Text(relatedTerm),
                  onPressed: () {
                    // Would navigate to related term
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    String content,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildExample(BuildContext context, GlossaryExample example) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            example.scenario,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            example.explanation,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color.shade700,
        ),
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return Colors.green;
      case 'intermediate':
        return Colors.orange;
      case 'advanced':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}