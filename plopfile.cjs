
export default (plop) => {
  plop.setGenerator('route', {
    description: 'Nova rota + service + teste',
    prompts: [{ type: 'input', name: 'name', message: 'Nome do recurso?' }],
    actions: [
      { type: 'add', path: 'api/src/http/{{camelCase name}}.ts', templateFile: 'templates/route.hbs' },
      { type: 'add', path: 'api/src/services/{{camelCase name}}Service.ts', templateFile: 'templates/service.hbs' }
    ]
  });
};
