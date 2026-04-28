import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../services/database_service.dart';

class EditExpenseScreen extends StatefulWidget {
  final Expense expense;

  const EditExpenseScreen({super.key, required this.expense});

  @override
  State<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  final _db = DatabaseService();

  late ExpenseCategory _selectedCategory;
  late DateTime _selectedDate;
  late bool _isRecurring;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.expense.title);
    _amountController = TextEditingController(
      text: widget.expense.amount.toStringAsFixed(2),
    );
    _notesController = TextEditingController(text: widget.expense.notes ?? '');
    _selectedCategory = widget.expense.category;
    _selectedDate = widget.expense.date;
    _isRecurring = widget.expense.isRecurring;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final updated = widget.expense.copyWith(
      title: _titleController.text.trim(),
      amount: double.parse(_amountController.text),
      date: _selectedDate,
      categoryId: _selectedCategory.id,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      isRecurring: _isRecurring,
    );

    try {
      await _db.updateExpense(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Expense updated!'),
            ],
          ),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppTheme.danger,
        ),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Expense'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildAmountSection(),
            const SizedBox(height: 24),
            _buildSectionLabel('What did you buy?'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'e.g. Lunch at McDonald\'s',
                prefixIcon: Icon(Icons.edit_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            _buildSectionLabel('Category'),
            const SizedBox(height: 12),
            _buildCategoryGrid(),
            const SizedBox(height: 24),
            _buildSectionLabel('Date'),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardSurface(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, color: AppTheme.textGrey),
                    const SizedBox(width: 12),
                    Text(
                      Formatters.dateLong(_selectedDate),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right, color: AppTheme.textGrey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionLabel('Notes (optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Add any additional details...',
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.cardSurface(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                title: const Text(
                  'Recurring expense',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                value: _isRecurring,
                activeThumbColor: AppTheme.primaryGreen,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) => setState(() => _isRecurring = value),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveChanges,
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save),
                          SizedBox(width: 8),
                          Text('Save Changes', style: TextStyle(fontSize: 16)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.textGrey,
      ),
    );
  }

  Widget _buildAmountSection() {
    return Card(
      color: AppTheme.primaryGreen,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'Amount',
              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'RM',
                  style: TextStyle(color: Colors.white70, fontSize: 28, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                IntrinsicWidth(
                  child: TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) return 'Invalid';
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: ExpenseCategory.allCategories.length,
      itemBuilder: (context, index) {
        final category = ExpenseCategory.allCategories[index];
        final isSelected = _selectedCategory.id == category.id;

        return InkWell(
          onTap: () => setState(() => _selectedCategory = category),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? category.color.withValues(alpha: 0.2) : AppTheme.cardSurface(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? category.color : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(category.icon, color: category.color, size: 24),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    category.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}