import 'package:supabase_flutter/supabase_flutter.dart';
import 'allergies.dart';
import 'auth_callback.dart';
import 'package:flutter/material.dart';
import 'data.dart';
import 'ui.dart';
import 'faithful_app.dart';

class AccountFlow extends StatefulWidget {
  final KitchenStore s;
  final VoidCallback onReady;
  final int confirmationReturn;
  const AccountFlow(
    this.s, {
    required this.onReady,
    this.confirmationReturn = 0,
    super.key,
  });
  @override
  State<AccountFlow> createState() => _AccountFlowState();
}

class _AccountFlowState extends State<AccountFlow> {
  String page = 'welcome';
  bool visible = false, busy = false;
  bool awaitingConfirmation = false;
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController();
  @override
  void initState() {
    super.initState();
    if (widget.confirmationReturn > 0) {
      page = 'login';
      awaitingConfirmation = true;
    }
  }

  @override
  void didUpdateWidget(covariant AccountFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.confirmationReturn != oldWidget.confirmationReturn) {
      page = 'login';
      awaitingConfirmation = true;
    }
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> enter() async {
    if (!widget.s.onboarded) {
      await present(context, OriginalOnboarding(widget.s));
      if (!widget.s.onboarded) return;
    }
    widget.onReady();
  }

  Future<void> explore() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final cloud = widget.s.cloud;
      if (cloud != null && !cloud.usingGuestKitchen) await cloud.signOut();
      if (mounted) await enter();
    } catch (_) {
      if (mounted) {
        toast(context, 'Unable to open the guest kitchen. Try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> authenticate() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    final cloud = widget.s.cloud;
    try {
      if (cloud?.client == null) {
        throw const AuthException(
          'Account service is not configured. Please contact the app administrator.',
        );
      }
      if (page == 'signup') {
        final result = await cloud!.client!.auth.signUp(
          email: email.text.trim(),
          password: password.text,
          emailRedirectTo: confirmationRedirect,
          data: {'display_name': name.text.trim()},
        );
        if (result.session == null) {
          if (mounted) {
            toast(
              context,
              'Check your email to confirm your account, then log in.',
            );
            setState(() {
              page = 'confirm';
              awaitingConfirmation = true;
            });
          }
          return;
        }
      } else {
        await cloud!.client!.auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
      await cloud.bind();
      if (!widget.s.onboarded) {
        widget.s.name =
            cloud.client!.auth.currentUser?.userMetadata?['display_name'] ??
            name.text.trim();
        await widget.s.save();
      }
      password.clear();
      if (mounted) {
        toast(context, 'Signed in successfully');
        await enter();
      }
    } on AuthException catch (e) {
      if (mounted && e.code == 'email_not_confirmed') {
        setState(() => awaitingConfirmation = true);
      }
      if (mounted) toast(context, e.message);
    } catch (_) {
      if (mounted) {
        toast(
          context,
          'Unable to sign in. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resendConfirmation() async {
    final address = email.text.trim();
    if (!address.contains('@') || address.endsWith('@')) {
      toast(context, 'Enter your email address first.');
      return;
    }
    setState(() => busy = true);
    try {
      final client = widget.s.cloud?.client;
      if (client == null) {
        throw const AuthException('Account service unavailable.');
      }
      await client.auth.resend(
        type: OtpType.signup,
        email: address,
        emailRedirectTo: confirmationRedirect,
      );
      if (mounted) {
        toast(
          context,
          'Confirmation requested. Check your inbox and spam folder.',
        );
      }
    } on AuthException catch (e) {
      if (mounted) toast(context, e.message);
    } catch (_) {
      if (mounted) {
        toast(
          context,
          'Unable to send email. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    if (page == 'welcome') {
      return Scaffold(
        backgroundColor: const Color(0xffff505b),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ClipRect(
                  child: Stack(
                    children: [
                      Positioned(
                        top: -65,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Image.asset(
                            'assets/entry-reference.png',
                            width: 350,
                            fit: BoxFit.fitWidth,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 16,
                          color: const Color(0xffff505b),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const Text(
                      'Dishcovery',
                      style: TextStyle(
                        fontFamily: 'Lobster',
                        fontSize: 49,
                        color: Colors.white,
                      ),
                    ),
                    gap(13),
                    Text(
                      'A little inspiration.\nA whole lot of delicious possibilities.',
                      textAlign: TextAlign.center,
                      style: type(13, color: Colors.white),
                    ),
                    gap(28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: green,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => setState(() => page = 'signup'),
                        child: const Text('Get started'),
                      ),
                    ),
                    TextButton(
                      onPressed: busy ? null : explore,
                      child: Text(
                        'Take a look around · Explore demo',
                        style: type(12, color: Colors.white),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => page = 'login'),
                      child: Text(
                        'Already have an account? Log in',
                        style: type(12, color: Colors.white),
                      ),
                    ),
                    gap(20),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    final signup = page == 'signup';
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Go back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => page = 'welcome'),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: OriginalPageEnter(
        key: ValueKey(page),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 30),
          child: Form(
            key: form,
            child: Column(
              children: [
                gap(25),
                Image.asset('assets/original-logo.png', width: 65, height: 65),
                gap(8),
                brand(),
                gap(10),
                if (page == 'confirm') ...[
                  Text(
                    'Check your email',
                    style: type(27, weight: FontWeight.w700),
                  ),
                  gap(10),
                  Text(
                    'Open the confirmation link sent to ${email.text.trim()} on this phone, then sign in to your kitchen.',
                    textAlign: TextAlign.center,
                  ),
                  gap(20),
                  primary(
                    'Continue to login',
                    () => setState(() => page = 'login'),
                  ),
                  TextButton(
                    onPressed: busy ? null : resendConfirmation,
                    child: const Text('Resend confirmation email'),
                  ),
                ] else ...[
                  Text(
                    signup ? 'Your kitchen awaits.' : 'Welcome back.',
                    style: type(27, weight: FontWeight.w700),
                  ),
                  gap(10),
                  Text(
                    signup
                        ? 'Discover something delicious every day.'
                        : 'A little inspiration is waiting for you.',
                    style: type(12, color: muted),
                  ),
                  gap(30),
                  if (signup)
                    fieldLabel(
                      'Your name',
                      TextFormField(
                        controller: name,
                        decoration: inputBox(hint: 'What should we call you?'),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter your name'
                            : null,
                      ),
                    ),
                  fieldLabel(
                    'Email',
                    TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: inputBox(hint: 'you@example.com'),
                      validator: (v) =>
                          RegExp(
                            r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                          ).hasMatch(v ?? '')
                          ? null
                          : 'Enter a valid email',
                    ),
                  ),
                  fieldLabel(
                    'Password',
                    TextFormField(
                      controller: password,
                      obscureText: !visible,
                      decoration: inputBox(
                        hint: signup
                            ? 'At least 8 characters'
                            : 'Your password',
                        suffix: IconButton(
                          tooltip: visible ? 'Hide password' : 'Show password',
                          onPressed: () => setState(() => visible = !visible),
                          icon: Icon(
                            visible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (v) => (v?.length ?? 0) < 8
                          ? 'Use at least 8 characters'
                          : null,
                    ),
                  ),
                  gap(10),
                  primary(
                    busy
                        ? 'Please wait…'
                        : signup
                        ? 'Create an Account  →'
                        : 'Log in  →',
                    busy ? null : authenticate,
                  ),
                  if (!signup && awaitingConfirmation)
                    TextButton(
                      onPressed: busy ? null : resendConfirmation,
                      child: const Text('Resend confirmation email'),
                    ),
                  gap(20),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        signup
                            ? 'Already have an account?'
                            : 'New to Dishcovery?',
                        style: type(12),
                      ),
                      TextButton(
                        onPressed: () {
                          form.currentState?.reset();
                          password.clear();
                          setState(() => page = signup ? 'login' : 'signup');
                        },
                        child: Text(signup ? 'Log in' : 'Get started'),
                      ),
                    ],
                  ),
                  gap(20),
                  Text(
                    'Sign in to sync your kitchen across your devices.',
                    textAlign: TextAlign.center,
                    style: type(11, color: muted),
                  ),
                  TextButton(
                    onPressed: busy ? null : explore,
                    child: const Text('Explore without an account'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OriginalOnboarding extends StatefulWidget {
  final KitchenStore s;
  const OriginalOnboarding(this.s, {super.key});
  @override
  State<OriginalOnboarding> createState() => _OriginalOnboardingState();
}

class _OriginalOnboardingState extends State<OriginalOnboarding> {
  int step = 0;
  late String purpose = widget.s.wellness['purpose'] ?? 'Recipes',
      skill = widget.s.skill;
  late final name = TextEditingController(
        text: widget.s.name == 'Home cook' ? '' : widget.s.name,
      ),
      bio = TextEditingController(text: widget.s.bio),
      age = TextEditingController(text: '${widget.s.wellness['age'] ?? ''}'),
      height = TextEditingController(
        text: '${widget.s.wellness['height'] ?? ''}',
      ),
      weight = TextEditingController(
        text: '${widget.s.wellness['weight'] ?? ''}',
      );
  late final cuisines = widget.s.cuisines.toSet(),
      allergies = widget.s.allergies.toSet();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    for (final c in [name, bio, age, height, weight]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> next() async {
    if (!form.currentState!.validate()) return;
    if (step < 5) {
      setState(() => step++);
      return;
    }
    final s = widget.s;
    s.name = name.text.trim();
    s.bio = bio.text.trim();
    s.skill = skill;
    s.cuisines = cuisines.toList();
    s.allergies = allergies.toList();
    s.wellness = {
      'purpose': purpose,
      'complete': true,
      'age': num.tryParse(age.text),
      'height': num.tryParse(height.text),
      'weight': num.tryParse(weight.text),
    };
    s.onboarded = true;
    await s.save();
    if (mounted) {
      if (s.storageError != null) {
        toast(context, s.storageError!);
      } else {
        Navigator.pop(context);
      }
    }
  }

  Widget option(String title, String sub, bool selected, VoidCallback tap) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: tap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: selected ? pale : Colors.white,
              border: Border.all(color: selected ? green : line),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: type(16, weight: FontWeight.w700)),
                      if (sub.isNotEmpty) ...[
                        gap(8),
                        Text(sub, style: type(12, color: muted)),
                      ],
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? green : muted,
                ),
              ],
            ),
          ),
        ),
      );
  Widget measure(
    String title,
    TextEditingController controller,
    double min,
    double max,
  ) => fieldLabel(
    title,
    TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: inputBox(hint: 'Optional'),
      validator: (v) {
        if (v == null || v.isEmpty) return null;
        final n = double.tryParse(v);
        return n == null || !n.isFinite || n < min || n > max
            ? 'Enter $min–$max'
            : null;
      },
    ),
  );
  @override
  Widget build(BuildContext c) {
    final titles = [
      'What brings you to Dishcovery?',
      'A little about your starting point.',
      'Let’s make this your kitchen.',
      'Find your cooking rhythm.',
      'What do you love to eat?',
      'Anything to look out for?',
    ];
    final subtitles = [
      'Choose your main reason. You can change it later.',
      'Optional details for your fitness profile. Stored only on this device.',
      'Just a few details to get started.',
      'Choose the level that feels like you.',
      'Pick your favorites.',
      'We’ll flag recipes with these declared allergens.',
    ];
    return Scaffold(
      appBar: pageHeader(c, 'Make it yours'),
      body: OriginalPageEnter(
        key: ValueKey(step),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (int i = 0; i < 6; i++)
                      Expanded(
                        child: Container(
                          height: 4,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: i <= step ? green : line,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                  ],
                ),
                gap(28),
                if (step > 0)
                  TextButton.icon(
                    onPressed: () => setState(() => step--),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Previous step'),
                  ),
                label('STEP ${step + 1} OF 6'),
                gap(15),
                Text(titles[step], style: type(29, weight: FontWeight.w700)),
                gap(15),
                Text(subtitles[step], style: type(13, color: muted)),
                gap(25),
                if (step == 0) ...[
                  for (final pair in [
                    (
                      'Fitness',
                      'Explore calories and macros alongside your meals.',
                    ),
                    (
                      'Recipes',
                      'Discover new dishes and build your own cookbook.',
                    ),
                    ('Community', 'Find inspiration from other home cooks.'),
                  ])
                    option(
                      pair.$1,
                      pair.$2,
                      purpose == pair.$1,
                      () => setState(() => purpose = pair.$1),
                    ),
                ],
                if (step == 1) ...[
                  measure('Age (years)', age, 1, 120),
                  measure('Height (cm)', height, 30, 250),
                  measure('Weight (kg)', weight, 2, 400),
                  gap(16),
                  Text(
                    'These details are optional. You can enjoy recipes and the community without them. Fitness users can optionally set up an estimated calorie plan in the daily tracker.',
                    style: type(12, color: muted),
                  ),
                ],
                if (step == 2) ...[
                  fieldLabel(
                    'Your name',
                    TextFormField(
                      controller: name,
                      decoration: inputBox(),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Enter your name' : null,
                    ),
                  ),
                  fieldLabel(
                    'A little about you',
                    TextFormField(
                      controller: bio,
                      maxLines: 3,
                      decoration: inputBox(),
                    ),
                  ),
                ],
                if (step == 3) ...[
                  for (final level in [
                    'Beginner',
                    'Intermediate',
                    'Professional',
                  ])
                    option(
                      level,
                      '',
                      skill == level,
                      () => setState(() => skill = level),
                    ),
                ],
                if (step == 4 || step == 5)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final value
                          in step == 4
                              ? categories
                              : {...allergensList, ...allergies}.toList())
                        FilterChip(
                          label: Text(value),
                          selected: (step == 4 ? cuisines : allergies).contains(
                            value,
                          ),
                          onSelected: (v) => setState(() {
                            final set = step == 4 ? cuisines : allergies;
                            v ? set.add(value) : set.remove(value);
                          }),
                        ),
                    ],
                  ),
                if (step == 5) ...[
                  CustomAllergies(
                    values: allergies,
                    onChanged: () => setState(() {}),
                  ),
                  gap(20),
                  Text(
                    'Always check ingredient labels and preparation conditions.',
                    style: type(12, color: muted),
                  ),
                ],
                gap(32),
                primary(step == 5 ? 'Let’s get cooking' : 'Continue', next),
                if (step == 1)
                  Center(
                    child: TextButton(
                      onPressed: () {
                        age.clear();
                        height.clear();
                        weight.clear();
                        setState(() => step++);
                      },
                      child: const Text('Skip for now'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
