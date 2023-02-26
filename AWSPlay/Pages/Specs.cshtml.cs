using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Amazon.DynamoDBv2.DataModel;

namespace AWSPlay.Pages
{
    public class SpecsModel : PageModel
    {
        private readonly IDynamoDBContext _context;

        public List<Spec>? Specs { get; set; }
        
        public SpecsModel(IDynamoDBContext context)
        {
            _context = context;
        }

        public async Task OnGet()
        {
            Specs = await _context.ScanAsync<Spec>(new ScanCondition[] { }).GetNextSetAsync();
        }
    }

    [DynamoDBTable("awsplay")]
    public class Spec
    {
        [DynamoDBHashKey("id")]
        public string? Id { get; set; }
        [DynamoDBProperty("value")]
        public string? Value { get; set; }
    }
}
