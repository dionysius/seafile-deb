import os
import yaml
import json
import logging

logger = logging.getLogger(__name__)


def _read_yaml(yaml_file_path=None, component_name=None):
    if yaml_file_path:
        if not os.path.isfile(yaml_file_path) or (not yaml_file_path.endswith('yml') and not yaml_file_path.endswith('yaml')):
            logger.warning(f'{yaml_file_path} is not existed or not a valid YAML file')
            return {}

        # First read, get vars from global.
        configs = {}
        with open(yaml_file_path, 'r', encoding='utf-8') as yaml_file:
            current_yaml_config = yaml.safe_load(yaml_file) or {}
            configs = current_yaml_config.get('global', {})
            if component_name:
                component_config = current_yaml_config.get(component_name, {})
                configs.update(component_config)
                if 'from_yaml' in component_config:
                    del configs['from_yaml']
                    configs.update(_read_yaml(component_config['from_yaml']))
        return configs
    return {}


def _check_type(func):
    def wrapper(self, key, default=None, check_type=True):
        result = func(self, key, default)
        if check_type:
            need_type = type(default)
            if need_type in (int, float):
                try:
                    result = need_type(result)
                except:
                    raise ValueError(f'Type of {key} must be a number')
            elif need_type == bool:
                if isinstance(result, str):
                    result = result.lower() in ('true', '1')
                else:
                    result = bool(result)
            elif need_type in (str, list, dict):
                result = need_type(result)
        return result
    return wrapper


class ConfigParser(object):
    def __init__(self, yaml_file_path, component_name):
        assert yaml_file_path and component_name, "yaml_file_path and component_name must be specified in initilizing ConfigParser"
        self.refresh_yaml_configs(yaml_file_path, component_name)

    def refresh_yaml_configs(self, yaml_file_path=None, component_name=None):
        self.yaml_file_path = yaml_file_path or self.yaml_file_path
        self.component_name = component_name or self.component_name
        try:
            self.yaml_configs = _read_yaml(self.yaml_file_path, self.component_name)
        except Exception as e:
            logger.error(f'Failure to read YAML config file: {e}')
            raise

    @_check_type
    def get(self, key, default=None):
        if key in os.environ:
            value = os.getenv(key)
            try:
                value = json.loads(value)
            except:
                pass
            return value
        return self.yaml_configs.get(key, default)
