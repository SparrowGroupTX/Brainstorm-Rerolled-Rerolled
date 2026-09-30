"""Include the manufactured teacher-data contracts in ordinary regressions."""
import unittest
from tools.advisor_learning import test_public_context, test_teacher_demonstrations


def load_tests(loader, tests, pattern):
    return unittest.TestSuite((loader.loadTestsFromModule(test_public_context),
                               loader.loadTestsFromModule(test_teacher_demonstrations)))
