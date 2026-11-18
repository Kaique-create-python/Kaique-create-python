"""Regressão do analisador leve: callbacks tipados não criam falso nome sem declaração."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('bb_lint', Path(__file__).resolve().parents[1] / 'tools/lint.py')
lint = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lint)


class CallbackNames(unittest.TestCase):
    def test_nested_callback_parameters_remain_declared(self):
        source = 'function T.novo(aoApertar: () -> (), aoSoltar: (() -> ())?): any\n aoSoltar()\nend'
        self.assertTrue({'aoApertar', 'aoSoltar'} <= lint.declarados(source))

    def test_typed_callbacks_do_not_swallow_next_function(self):
        source = 'local function x(a: (number, string) -> (), b: number)\nend\nfunction T.y(c: string, d: () -> ())\nend'
        self.assertTrue({'a', 'b', 'c', 'd'} <= lint.declarados(source))

    def test_numeric_for_counters_are_declared_with_or_without_spaces(self):
        source = 'for i=1,10 do end\nfor j = 1,5 do end\nfor k,v in pairs(a) do end'
        self.assertTrue({'i', 'j', 'k', 'v'} <= lint.declarados(source))


if __name__ == '__main__': unittest.main()
